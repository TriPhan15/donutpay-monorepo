import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';
import 'package:finance_ai_app/screens/dashboard/widgets/home_header_band.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_header_band.dart';
import 'package:finance_ai_app/widgets/common/amount_eye_button.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';

void main() {
  final calls = <String>[];
  late TextEditingController search;

  setUp(() {
    calls.clear();
    search = TextEditingController();
  });
  tearDown(() => search.dispose());

  StatsHeaderBand band({
    bool searching = false,
    bool filterActive = false,
    double income = 18500000,
    double expense = 6020000,
    LedgerPeriod period = LedgerPeriod.month,
  }) => StatsHeaderBand(
    periodLabel: 'Tháng 10/2026',
    period: period,
    income: income,
    expense: expense,
    filterActive: filterActive,
    searching: searching,
    searchController: search,
    onSearchOpen: () => calls.add('search'),
    onSearchClose: () => calls.add('close'),
    onSearchChanged: (v) => calls.add('type $v'),
    onFilter: () => calls.add('filter'),
    onExport: () => calls.add('export'),
    onPrevious: () => calls.add('previous'),
    onNext: () => calls.add('next'),
    onPickDate: () => calls.add('pick'),
    onPeriodChanged: (p) => calls.add('period ${p.name}'),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    FakeSettingsRepository? settings,
    ThemeMode mode = ThemeMode.light,
    Size size = const Size(400, 800),
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
            child: SingleChildScrollView(child: child),
          ),
        ),
        settings: settings ?? FakeSettingsRepository(themeMode: mode),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'title row: Thống kê with round search, filter and Excel buttons',
    (tester) async {
      await pump(tester, band());
      final title = tester.widget<Text>(find.text('Thống kê'));
      expect(title.style?.fontSize, AppTextSize.pageTitle);
      expect(title.style?.color, Colors.white);
      await tester.tap(find.byKey(StatsHeaderBand.searchKey));
      await tester.tap(find.byKey(StatsHeaderBand.filterKey));
      await tester.tap(find.byKey(StatsHeaderBand.exportKey));
      expect(calls, ['search', 'filter', 'export']);
      final context = tester.element(find.byType(StatsHeaderBand));
      final box = tester.widget<Container>(find.byKey(StatsHeaderBand.bandKey));
      expect(
        (box.decoration as BoxDecoration).gradient,
        context.colors.headerGradient,
      );
    },
  );

  testWidgets('the filter button is filled white when a filter is on', (
    tester,
  ) async {
    Color? fill() => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byKey(StatsHeaderBand.filterKey),
                matching: find.byType(Material),
              )
              .first,
        )
        .color;
    await pump(tester, band());
    expect(fill(), isNot(Colors.white));
    await pump(tester, band(filterActive: true));
    expect(fill(), Colors.white);
  });

  testWidgets('period row: eye left, ‹ label › centred, period menu right', (
    tester,
  ) async {
    await pump(tester, band());
    final eye = tester.getCenter(find.byType(AmountEyeButton)).dx;
    final previous = tester
        .getCenter(find.byKey(StatsHeaderBand.previousKey))
        .dx;
    final label = tester.getCenter(find.text('Tháng 10/2026')).dx;
    final next = tester.getCenter(find.byKey(StatsHeaderBand.nextKey)).dx;
    final menu = tester.getCenter(find.byKey(StatsHeaderBand.periodMenuKey)).dx;
    expect(
      eye < previous && previous < label && label < next && next < menu,
      isTrue,
    );

    await tester.tap(find.byKey(StatsHeaderBand.previousKey));
    await tester.tap(find.text('Tháng 10/2026'));
    await tester.tap(find.byKey(StatsHeaderBand.nextKey));
    await tester.tap(find.byKey(StatsHeaderBand.periodMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Năm').last);
    await tester.pumpAndSettle();
    expect(calls, ['previous', 'pick', 'next', 'period year']);
  });

  testWidgets('the three pills hide together with the home balance', (
    tester,
  ) async {
    final settings = FakeSettingsRepository()..amountsHidden = false;
    await pump(
      tester,
      Column(
        children: [
          band(),
          HomeHeaderBand(
            userName: 'An',
            balance: 1000000,
            pendingChange: 0,
            monthIncome: 18500000,
            monthExpense: 6020000,
            unreadNotifications: ValueNotifier<int>(0),
            onOpenNotifications: () {},
            onAddTransaction: () {},
            onOpenBudgets: () {},
            onOpenSavings: () {},
          ),
        ],
      ),
      settings: settings,
      size: const Size(400, 1400),
    );
    expect(find.text('Thu 18,5 tr'), findsWidgets);
    expect(find.text('Chi 6,02 tr'), findsWidgets);
    expect(find.text('Còn 12,48 tr'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(StatsHeaderBand),
        matching: find.byType(AmountEyeButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Còn 12,48 tr'), findsNothing);
    expect(find.text('Thu 18,5 tr'), findsNothing);
    expect(find.text('1.000.000 đ'), findsNothing, reason: 'home hides too');
    expect(find.textContaining(AmountEyeButton.hiddenText), findsWidgets);
    expect(settings.amountsHidden, isTrue);
  });

  testWidgets('Còn is income minus expense and may be negative', (
    tester,
  ) async {
    final settings = FakeSettingsRepository()..amountsHidden = false;
    await pump(
      tester,
      band(income: 100000, expense: 500000),
      settings: settings,
    );
    expect(find.text('Còn -400k'), findsOneWidget);
  });

  testWidgets('search replaces the title row with a white field, ✕ closes it', (
    tester,
  ) async {
    await pump(tester, band(searching: true));
    expect(find.text('Thống kê'), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.filled, isTrue);
    await tester.enterText(find.byType(TextField), 'cafe');
    await tester.tap(find.byKey(StatsHeaderBand.closeSearchKey));
    expect(calls, ['type cafe', 'close']);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('fits 320 px at text scale 1.3 (${mode.name})', (tester) async {
      final settings = FakeSettingsRepository(themeMode: mode)
        ..amountsHidden = false;
      await pump(
        tester,
        band(income: 123456789000, expense: 98765432100),
        settings: settings,
        size: const Size(320, 800),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      // Label and pills wrap to two lines instead of cutting. Whether the text fits cannot be measured here: the
      // test font is 1 em per glyph, far wider than Be Vietnam Pro.
      expect(tester.widget<Text>(find.text('Tháng 10/2026')).maxLines, 2);
      expect(tester.widget<Text>(find.text('Thu 123,46 tỷ')).maxLines, 2);
    });
  }
}
