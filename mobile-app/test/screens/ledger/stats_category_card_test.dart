import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_category_card.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';

const List<CategoryShare> _shares = [
  CategoryShare(category: 'Ăn uống', amount: 2450000, count: 38, percent: 40.7),
  CategoryShare(category: 'Mua sắm', amount: 1900000, count: 12, percent: 31.6),
  CategoryShare(
    category: 'Di chuyển',
    amount: 820000,
    count: 21,
    percent: 13.6,
  ),
  CategoryShare(category: 'Hóa đơn', amount: 850000, count: 1, percent: 14.1),
];

void main() {
  Future<BuildContext> pump(
    WidgetTester tester,
    List<CategoryShare> shares, {
    ThemeMode mode = ThemeMode.light,
    Size size = const Size(400, 1000),
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
              child: StatsCategoryCard(
                shares: shares,
                periodLabel: 'Tháng 10/2026',
              ),
            ),
          ),
        ),
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(StatsCategoryCard));
  }

  testWidgets(
    'the ring is split in category colours with the total spent in the middle',
    (tester) async {
      final context = await pump(tester, _shares);
      final colors = Theme.of(context).colorScheme;
      final pie = tester.widget<PieChart>(find.byType(PieChart));
      expect(pie.data.sections, hasLength(4));
      expect(
        pie.data.sections.first.color,
        CategoryColors.accentFor('Ăn uống', colors),
      );
      expect(pie.data.sections.first.value, 2450000);
      expect(pie.data.sections.every((s) => !s.showTitle), isTrue);
      expect(find.text('6,02 tr'), findsOneWidget);
      expect(find.text('đã chi'), findsOneWidget);
    },
  );

  testWidgets(
    'one row per category: tile, bar, compact amount, "41%, 38 lần"',
    (tester) async {
      final context = await pump(tester, _shares);
      expect(find.text('Theo danh mục'), findsOneWidget);
      expect(find.text('Tháng 10/2026'), findsOneWidget);
      expect(find.text('2,45 tr'), findsOneWidget);
      expect(find.text('41%, 38 lần'), findsOneWidget);
      expect(find.text('14%, 1 lần'), findsOneWidget);
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(bars, hasLength(4));
      expect(bars.first.value, closeTo(0.407, 0.001));
      expect(
        bars.first.valueColor?.value,
        CategoryColors.accentFor('Ăn uống', Theme.of(context).colorScheme),
      );
      expect(
        tester.widget<Text>(find.text('Ăn uống').last).style?.fontSize,
        AppTextSize.body,
      );
    },
  );

  testWidgets('no row says vượt', (tester) async {
    await pump(tester, _shares);
    expect(find.textContaining('vượt'), findsNothing);
  });

  testWidgets('no spending shows the empty line instead of a ring', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(find.byType(PieChart), findsNothing);
    expect(find.text('Chưa có khoản chi trong kỳ này'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('fits 320 px at text scale 1.3 (${mode.name})', (tester) async {
      await pump(
        tester,
        _shares,
        mode: mode,
        size: const Size(320, 1200),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
