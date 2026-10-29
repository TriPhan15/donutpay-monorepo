import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_chart_card.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';

List<ChartBucket> _buckets(int n, {double income = 0, double expense = 0}) => [
  for (var i = 0; i < n; i++)
    ChartBucket(
      start: n == 7 ? DateTime(2026, 10, 26 + i) : DateTime(2026, i + 1),
      income: income * (i + 1),
      expense: expense * (i + 1),
      isSelected: i == n - 1,
    ),
];

void main() {
  Future<BuildContext> pump(
    WidgetTester tester,
    StatsChartCard card, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: card),
        ),
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(StatsChartCard));
  }

  testWidgets('week shows 7 bars T2..CN, month 6 months, year 12', (
    tester,
  ) async {
    final context = await pump(
      tester,
      StatsChartCard(
        period: LedgerPeriod.week,
        buckets: _buckets(7, expense: 10),
      ),
    );
    BarChart chart() => tester.widget<BarChart>(find.byType(BarChart));
    expect(chart().data.barGroups, hasLength(7));
    for (final d in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
      expect(find.text(d), findsOneWidget);
    }
    final axis = tester.widget<Text>(find.text('T2'));
    expect(axis.style?.fontSize, AppTextSize.caption);
    expect(axis.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);

    await pump(
      tester,
      StatsChartCard(
        period: LedgerPeriod.month,
        buckets: [
          for (var m = 5; m <= 10; m++)
            ChartBucket(
              start: DateTime(2026, m),
              income: 1,
              expense: 1,
              isSelected: m == 10,
            ),
        ],
      ),
    );
    expect(chart().data.barGroups, hasLength(6));
    expect(find.text('Th5'), findsOneWidget);
    expect(find.text('Th10'), findsOneWidget);

    await pump(
      tester,
      StatsChartCard(
        period: LedgerPeriod.year,
        buckets: _buckets(12, income: 5),
      ),
    );
    expect(chart().data.barGroups, hasLength(12));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'each bucket is a green income bar and a red spending bar; other buckets faded to 0.4 (${mode.name})',
      (tester) async {
        final context = await pump(
          tester,
          StatsChartCard(
            period: LedgerPeriod.week,
            buckets: _buckets(7, income: 3, expense: 2),
          ),
          mode: mode,
        );
        final colors = Theme.of(context).colorScheme;
        final success = context.colors.successColor;
        final groups = tester
            .widget<BarChart>(find.byType(BarChart))
            .data
            .barGroups;
        expect(groups.last.barRods[0].color, success);
        expect(groups.last.barRods[1].color, colors.error);
        expect(groups.first.barRods[0].color, success.withValues(alpha: 0.4));
        expect(
          groups.first.barRods[1].color,
          colors.error.withValues(alpha: 0.4),
        );
        expect(groups.first.barRods[0].toY, 3);
        expect(groups.first.barRods[1].toY, 2);
      },
    );
  }

  testWidgets('tapping a bar shows its income and spending in full', (
    tester,
  ) async {
    await pump(
      tester,
      StatsChartCard(
        period: LedgerPeriod.month,
        buckets: [
          for (var m = 5; m <= 10; m++)
            ChartBucket(
              start: DateTime(2026, m),
              income: m == 9 ? 18500000 : 0,
              expense: m == 9 ? 6020000 : 0,
              isSelected: m == 10,
            ),
        ],
      ),
    );
    expect(find.text('Chạm cột để xem số'), findsOneWidget);
    await tester.tap(find.byKey(StatsChartCard.barKey(4)));
    await tester.pumpAndSettle();
    expect(find.text('Chạm cột để xem số'), findsNothing);
    expect(find.text('Thu 18.500.000 đ'), findsOneWidget);
    expect(find.text('Chi 6.020.000 đ'), findsOneWidget);
    final groups = tester
        .widget<BarChart>(find.byType(BarChart))
        .data
        .barGroups;
    expect(groups[4].barRods[0].color!.a, 1, reason: 'the tapped bar is lit');
  });

  testWidgets('all zero draws an empty chart without error', (tester) async {
    await pump(
      tester,
      StatsChartCard(period: LedgerPeriod.year, buckets: _buckets(12)),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Thu'), findsOneWidget);
    expect(find.text('Chi'), findsOneWidget);
  });
}
