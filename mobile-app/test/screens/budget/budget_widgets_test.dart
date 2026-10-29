import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/models/home_budget_summary.dart';
import 'package:finance_ai_app/screens/budget/widgets/budget_band_summary.dart';
import 'package:finance_ai_app/screens/budget/widgets/budget_group_card.dart';
import 'package:finance_ai_app/screens/budget/widgets/budget_period_tabs.dart';

BudgetProgress _progress({
  int id = 1,
  String? category = 'Ăn uống',
  double limit = 1000000,
  required double spent,
}) => BudgetProgress(
  budget: BudgetModel.forPeriod(
    id: id,
    categoryId: category == null ? null : id,
    categoryName: category,
    amount: limit,
    periodType: BudgetPeriodType.month,
    day: DateTime.now(),
  ),
  spent: spent,
);

Future<AppLocalizations> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeMode mode = ThemeMode.light,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late AppLocalizations loc;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(
        backgroundColor: AppTheme.primary,
        body: Builder(
          builder: (context) {
            loc = context.loc;
            return SingleChildScrollView(child: child);
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return loc;
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

Color? _barColor(WidgetTester tester, int id) => tester
    .widget<LinearProgressIndicator>(find.byKey(BudgetRow.barKey(id)))
    .color;

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mode.name}: the bar is red from 100%, orange from 80%, '
        'blue below', (tester) async {
      final items = [
        _progress(id: 1, spent: 1000000),
        _progress(id: 2, spent: 800000),
        _progress(id: 3, spent: 950000),
        _progress(id: 4, spent: 790000),
      ];
      await _pump(
        tester,
        BudgetGroupCard(
          kind: BudgetGroupKind.within,
          items: items,
          onTap: (_) {},
          onDelete: (_) async => false,
        ),
        mode: mode,
      );
      final theme = _theme(tester);

      expect(_barColor(tester, 1), theme.colorScheme.error);
      expect(_barColor(tester, 2), theme.semanticColors.warningColor);
      expect(_barColor(tester, 3), theme.semanticColors.warningColor);
      expect(_barColor(tester, 4), theme.colorScheme.primary);
    });

    testWidgets('${mode.name}: headers are tinted red for over, green for '
        'within', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            BudgetGroupCard(
              kind: BudgetGroupKind.over,
              items: [_progress(spent: 1400000)],
              onTap: (_) {},
              onDelete: (_) async => false,
            ),
            BudgetGroupCard(
              kind: BudgetGroupKind.within,
              items: [_progress(id: 2, spent: 10)],
              onTap: (_) {},
              onDelete: (_) async => false,
            ),
          ],
        ),
        mode: mode,
      );
      final theme = _theme(tester);
      Color? tint(BudgetGroupKind kind) => tester
          .widget<Container>(find.byKey(BudgetGroupCard.headerKey(kind)))
          .color;

      expect(
        tint(BudgetGroupKind.over),
        theme.colorScheme.error.withValues(
          alpha: BudgetGroupCard.headerTintAlpha,
        ),
      );
      expect(
        tint(BudgetGroupKind.within),
        theme.semanticColors.successColor.withValues(
          alpha: BudgetGroupCard.headerTintAlpha,
        ),
      );
    });
  }

  testWidgets('a row says what is left, or how much is over in red', (
    tester,
  ) async {
    final loc = await _pump(
      tester,
      Column(
        children: [
          BudgetGroupCard(
            kind: BudgetGroupKind.over,
            items: [_progress(id: 1, category: 'Mua sắm', spent: 1400000)],
            onTap: (_) {},
            onDelete: (_) async => false,
          ),
          BudgetGroupCard(
            kind: BudgetGroupKind.within,
            items: [_progress(id: 2, spent: 450000)],
            onTap: (_) {},
            onDelete: (_) async => false,
          ),
        ],
      ),
    );

    expect(find.text('Đang vượt'), findsOneWidget);
    expect(find.text('Trong mức'), findsOneWidget);
    expect(find.text('1 ngân sách'), findsNWidgets(2));

    final over = 'Vượt ${CurrencyHelper.formatCompactVND(400000, loc)}';
    expect(find.text(over), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(over)).style?.color,
      _theme(tester).colorScheme.error,
    );
    expect(
      find.text('Còn ${CurrencyHelper.formatCompactVND(550000, loc)}'),
      findsOneWidget,
    );
    expect(find.text('140%'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(
      find.text(
        '${CurrencyHelper.formatCompactVND(450000, loc)} / '
        '${CurrencyHelper.formatCompactVND(1000000, loc)}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a row reports its budget', (tester) async {
    BudgetProgress? tapped;
    final item = _progress(id: 9, spent: 10);
    await _pump(
      tester,
      BudgetGroupCard(
        kind: BudgetGroupKind.within,
        items: [item],
        onTap: (p) => tapped = p,
        onDelete: (_) async => false,
      ),
    );

    await tester.tap(find.text('Ăn uống'));
    expect(tapped, same(item));
  });

  testWidgets('a long category name fits a 320 px phone', (tester) async {
    await _pump(
      tester,
      BudgetGroupCard(
        kind: BudgetGroupKind.over,
        items: [
          _progress(
            category: 'Một danh mục có cái tên rất là dài dòng',
            spent: 3e9,
          ),
        ],
        onTap: (_) {},
        onDelete: (_) async => false,
      ),
      width: 320,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the band line shows the share spent and what is left', (
    tester,
  ) async {
    final summary = HomeBudgetSummary.from([
      _progress(category: null, limit: 8000000, spent: 6020000),
    ], DateTime.now())!;
    final loc = await _pump(tester, BudgetBandSummary(summary: summary));

    expect(find.text('75%'), findsOneWidget);
    expect(
      find.text('Còn ${CurrencyHelper.formatCompactVND(1980000, loc)}'),
      findsOneWidget,
    );
    expect(find.textContaining('Tháng này'), findsOneWidget);
  });

  testWidgets('the band line names how much the total is over', (tester) async {
    final summary = HomeBudgetSummary.from([
      _progress(category: null, limit: 1000000, spent: 1500000),
    ], DateTime.now())!;
    final loc = await _pump(tester, BudgetBandSummary(summary: summary));

    expect(
      find.text('Vượt ${CurrencyHelper.formatCompactVND(500000, loc)}'),
      findsOneWidget,
    );
  });

  testWidgets('the tabs report the tapped period', (tester) async {
    String? picked;
    await _pump(
      tester,
      BudgetPeriodTabs(
        selected: BudgetPeriodType.month,
        onChanged: (type) => picked = type,
      ),
    );

    await tester.tap(find.text('Năm'));
    expect(picked, BudgetPeriodType.year);
    expect(
      tester.widget<Text>(find.text('Tháng')).style?.color,
      AppTheme.primaryDark,
    );
  });
}
