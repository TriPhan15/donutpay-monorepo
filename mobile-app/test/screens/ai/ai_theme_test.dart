import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/spending_group_colors.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ai/ai_tab_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';

/// Today at noon, so that every transaction falls in this week and this month.
final DateTime _today = DateTime(
  DateTime.now().year,
  DateTime.now().month,
  DateTime.now().day,
  12,
);

Map<String, Object?> _tx(
  int id,
  num amount,
  String category, {
  bool isExpense = true,
}) => {
  'id': id,
  'title': category,
  'amount': amount,
  'date': _today.toIso8601String(),
  'category': category,
  'isExpense': isExpense,
};

/// Income 10M; needs 2M (20%, Ổn), wants 4M (40%, Hơi cao), savings 40% (Ổn).
final List<Map<String, Object?>> _transactions = [
  _tx(1, 10000000, 'Lương', isExpense: false),
  _tx(2, 2000000, 'Ăn uống'),
  _tx(3, 4000000, 'Giải trí'),
];

ResponseBody _patterns(List<Map<String, Object?>> patterns) =>
    jsonResponse(200, {'status': 'OK', 'patterns': patterns});

void main() {
  final backend = FakeBackend();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    // The AI tab also reads the transactions waiting to be sent; the fake keeps it away from a real database.
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});

    backend.reset();
    backend.on(
      'GET',
      '/api/transactions/mine',
      (_) => okResponse(_transactions),
    );
    backend.on('GET', '/api/savings', (_) => okResponse([]));
    backend.on(
      'POST',
      '/spade/analyze',
      (_) => _patterns([
        {
          'itemsets': [
            ['Ăn uống'],
            ['Giải trí'],
          ],
          'support': 3,
          'weight': 1.0,
          'weightedSupport': 0.125,
          'weeks': ['2026-W40'],
        },
      ]),
    );
  });

  // The language cubit of withAppSettings sets the default locale of intl.
  tearDown(() => Intl.defaultLocale = null);

  Future<void> start(WidgetTester tester, ThemeMode mode) async {
    // Tall, so that every card is built without scrolling, and wide, because the test font is much wider than a real one.
    tester.view.physicalSize = const Size(700, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        const AITabPage(),
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
  }

  ColorScheme colorsOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(AITabPage))).colorScheme;

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme', () {
      testWidgets(
        'the band takes the header gradient; rows take the surface and text colours of the theme',
        (tester) async {
          await start(tester, mode);
          await tester.pumpAndSettle();
          final colors = colorsOf(tester);
          final context = tester.element(find.byType(AITabPage));

          expect(
            boxDecoration(tester, find.text('Hôm nay tiêu được')).gradient,
            context.colors.headerGradient,
          );
          expect(boxColor(tester, find.text('Chi nhiều nhất')), colors.surface);
          expect(
            paintedColor(tester, find.text('Chi nhiều nhất')),
            colors.onSurface,
          );
          // Nothing was spent last month, so the trend row says what this month cost.
          expect(
            paintedColor(tester, find.textContaining('Tháng này bạn đã chi')),
            colors.onSurfaceVariant,
          );
          expect(
            paintedColor(
              tester,
              find.byIcon(Icons.local_fire_department_rounded),
            ),
            colors.primary,
          );
        },
      );

      testWidgets(
        'the chart: line, area, grid, labels and the touch tooltip follow the theme',
        (tester) async {
          await start(tester, mode);
          await tester.pumpAndSettle();
          final colors = colorsOf(tester);
          final chart = tester.widget<LineChart>(find.byType(LineChart)).data;
          final line = chart.lineBarsData.single;

          expect(line.color, colors.primary);
          expect(
            line.belowBarData.gradient!.colors.first,
            colors.primary.withValues(alpha: 0.35),
          );
          expect(
            chart.gridData.getDrawingHorizontalLine(0).color,
            colors.onSurfaceVariant.withValues(alpha: 0.1),
          );
          expect(
            paintedColor(
              tester,
              find
                  .descendant(
                    of: find.byType(LineChart),
                    matching: find.byType(Text),
                  )
                  .first,
            ),
            colors.onSurfaceVariant,
          );
          final tooltip = chart.lineTouchData.touchTooltipData;
          final spot = LineBarSpot(line, 0, line.spots.first);
          final item = tooltip.getTooltipItems([spot]).single!;
          expect(tooltip.getTooltipColor(spot), colors.surfaceContainer);
          expect(item.textStyle.color, colors.onSurface);
          expect(
            contrastRatio(item.textStyle.color!, colors.surfaceContainer),
            greaterThanOrEqualTo(4.5),
            reason: 'no dark text on a dark tooltip',
          );
        },
      );

      testWidgets(
        'balance: group colours from the theme palette, levels in the income and warning colours',
        (tester) async {
          await start(tester, mode);
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(AITabPage));
          final colors = colorsOf(tester);
          final swatches = tester
              .widgetList<Container>(find.byType(Container))
              .where((c) => c.constraints?.maxWidth == 10)
              .map((c) => (c.decoration! as BoxDecoration).color)
              .toList();

          expect(swatches, [
            colors.primary,
            SpendingGroupColors.wants,
            context.colors.incomeColor,
          ]);
          expect(
            paintedColor(tester, find.text('Hơi cao')),
            context.colors.warningColor,
          );
          expect(
            paintedColor(tester, find.text('Ổn').first),
            context.colors.incomeColor,
          );
        },
      );
    });
  }

  test('the AI tab has no hard-coded Material colours left (T9 spec 2.1)', () {
    final sources = [
      File('lib/screens/ai/ai_tab_page.dart'),
      ...Directory(
        'lib/screens/ai/widgets',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart')),
    ];
    final hardCoded = RegExp(r'\bColors\.(?!transparent\b)\w+|\bColor\(0x');
    for (final file in sources) {
      expect(
        hardCoded.allMatches(file.readAsStringSync()).map((m) => m.group(0)),
        isEmpty,
        reason: file.path,
      );
    }
  });
}
