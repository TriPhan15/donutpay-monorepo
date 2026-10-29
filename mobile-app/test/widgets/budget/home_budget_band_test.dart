import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/models/home_budget_summary.dart';
import 'package:finance_ai_app/widgets/budget/home_budget_band.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';

void main() {
  final today = DateTime(2026, 10, 20);

  // The language cubit of withAppSettings sets the default locale of intl.
  tearDown(() => Intl.defaultLocale = null);

  BudgetProgress progress(double limit, double spent, {String? category}) =>
      BudgetProgress(
        budget: BudgetModel.forPeriod(
          categoryName: category,
          amount: limit,
          periodType: BudgetPeriodType.month,
          day: today,
        ),
        spent: spent,
      );

  HomeBudgetSummary summaryOf(List<BudgetProgress> active) =>
      HomeBudgetSummary.from(active, today)!;

  var opened = 0;
  var retried = 0;

  Future<void> showBand(
    WidgetTester tester, {
    HomeBudgetSummary? summary,
    bool loadFailed = false,
    ThemeMode mode = ThemeMode.light,
    double width = 400,
    double textScale = 1,
    bool settle = true,
  }) async {
    opened = 0;
    retried = 0;
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        settings: FakeSettingsRepository(themeMode: mode),
        MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: Scaffold(
            body: ListView(
              children: [
                HomeBudgetBand(
                  // A new key per pump: the ring animates again from 0, as on a new screen.
                  key: UniqueKey(),
                  summary: summary,
                  loadFailed: loadFailed,
                  onOpen: () => opened++,
                  onRetry: () => retried++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  CircularProgressIndicator ring(WidgetTester tester) =>
      tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );

  ThemeData themeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(HomeBudgetBand)));

  testWidgets(
    'shows the ring percent, what is left for how many days and a View button',
    (tester) async {
      await showBand(tester, summary: summaryOf([progress(8000000, 6020000)]));

      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Còn 1,98 tr cho 12 ngày'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Xem'), findsOneWidget);
    },
  );

  testWidgets('an exceeded total says by how much, in the error colour', (
    tester,
  ) async {
    await showBand(tester, summary: summaryOf([progress(1000000, 1400000)]));

    expect(find.text('Đã vượt 400k'), findsOneWidget);
    expect(find.text('140%'), findsOneWidget);
    final scheme = themeOf(tester).colorScheme;
    expect(ring(tester).color, scheme.error);
    expect(
      tester.widget<Text>(find.text('Đã vượt 400k')).style?.color,
      scheme.error,
    );
  });

  testWidgets('the ring is primary below 80, warning from 80, error from 100', (
    tester,
  ) async {
    for (final (spent, expected) in [
      (790000.0, 'primary'),
      (800000.0, 'warning'),
      (1000000.0, 'error'),
    ]) {
      await showBand(tester, summary: summaryOf([progress(1000000, spent)]));
      final theme = themeOf(tester);
      final color = switch (expected) {
        'primary' => theme.colorScheme.primary,
        'warning' => theme.semanticColors.warningColor,
        _ => theme.colorScheme.error,
      };
      expect(ring(tester).color, color, reason: '$spent');
    }
  });

  testWidgets('the ring runs from 0 to its value once shown', (tester) async {
    await showBand(
      tester,
      summary: summaryOf([progress(8000000, 6020000)]),
      settle: false,
    );
    await tester.pump();
    expect(ring(tester).value, 0);

    await tester.pump(const Duration(milliseconds: 600));
    expect(ring(tester).value, closeTo(6020000 / 8000000, 0.0001));
  });

  testWidgets(
    'the second line names the most exceeded category, else the near one, else nothing',
    (tester) async {
      await showBand(
        tester,
        summary: summaryOf([
          progress(1000000, 850000, category: 'Ăn uống'),
          progress(1000000, 1400000, category: 'Mua sắm'),
        ]),
      );
      expect(find.text('Mua sắm đã vượt 400k'), findsOneWidget);

      await showBand(
        tester,
        summary: summaryOf([
          progress(1000000, 850000, category: 'Ăn uống'),
          progress(1000000, 100000, category: 'Di chuyển'),
        ]),
      );
      expect(find.text('Ăn uống đã dùng 85%'), findsOneWidget);

      await showBand(
        tester,
        summary: summaryOf([progress(1000000, 100000, category: 'Di chuyển')]),
      );
      expect(find.textContaining('đã vượt'), findsNothing);
      expect(find.textContaining('đã dùng'), findsNothing);
    },
  );

  testWidgets(
    'no budget invites to set one; a failed load offers retry instead',
    (tester) async {
      await showBand(tester);
      expect(find.text('Đặt ngân sách tháng này'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Đặt'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Đặt ngân sách tháng này'));
      expect(opened, 1);

      await showBand(tester, loadFailed: true);
      expect(find.text('Chưa tải được ngân sách'), findsOneWidget);
      expect(find.text('Đặt ngân sách tháng này'), findsNothing);
      await tester.tap(find.text('Thử lại'));
      expect(retried, 1);
      expect(opened, 0);
    },
  );

  testWidgets('tapping the band or View opens the budgets', (tester) async {
    await showBand(tester, summary: summaryOf([progress(8000000, 1000000)]));

    await tester.tap(find.text('Xem'));
    await tester.tap(find.text('12%'));
    expect(opened, 2);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mode.name}: fits 320 px at text scale 1.3, on a pale band', (
      tester,
    ) async {
      await showBand(
        tester,
        summary: summaryOf([
          progress(8000000, 6020000),
          progress(1000000, 1400000, category: 'Mua sắm'),
        ]),
        mode: mode,
        width: 320,
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      final scheme = themeOf(tester).colorScheme;
      final decoration = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(HomeBudgetBand),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.gradient != null);
      expect(decoration.gradient!.colors, [
        scheme.primaryContainer,
        scheme.surface,
      ]);
      expect(decoration.borderRadius, BorderRadius.circular(20));
    });
  }
}
