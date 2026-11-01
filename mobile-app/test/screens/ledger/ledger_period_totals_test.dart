import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/ledger_page.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_calendar_card.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_header_band.dart';
import 'package:finance_ai_app/services/budget_alert_tracker.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/fake_settings_repository.dart';

const String _mine = '/api/transactions/mine';

/// One transaction the fake server holds; the expected totals of every period are worked out from these.
class _Row {
  final int id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final String category;

  const _Row(
    this.id,
    this.title,
    this.amount,
    this.date, {
    this.isExpense = true,
    this.category = 'Ăn uống',
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'date': date.toIso8601String(),
    'category': category,
    'isExpense': isExpense,
  };

  bool get isSavings => isExpense && category == TransactionCategories.savings;
}

void main() {
  final backend = FakeBackend();
  final loc = lookupAppLocalizations(const Locale('vi'));
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 12);
  final lastWeek = today.subtract(const Duration(days: 7));
  final lastMonth = DateTime(now.year, now.month - 1, 1, 9);
  final lastYear = DateTime(now.year - 1, 6, 1, 9);

  late List<_Row> rows;

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
    BudgetAlertTracker.instance.resetMemory();
    BudgetAlertPresenter.resetQueue();
    TransactionCategories.expenseSelectable.clear();
    TransactionCategories.incomeSelectable.clear();

    rows = [
      _Row(1, 'Bữa trưa nay', 100000, today),
      _Row(2, 'Lương nay', 2000000, today, isExpense: false, category: 'Lương'),
      _Row(
        3,
        'Gửi tiết kiệm nay',
        500000,
        today,
        category: TransactionCategories.savings,
      ),
      _Row(4, 'Bữa trưa tuần trước', 7000, lastWeek),
      _Row(5, 'Bữa trưa tháng trước', 30000, lastMonth),
      _Row(6, 'Thưởng năm ngoái', 900000, lastYear, isExpense: false),
      _Row(7, 'Bữa trưa năm ngoái', 4000, lastYear),
    ];

    AppRepository.instance.localStore = FakeLocalStore();
    backend.reset();
    backend.on(
      'GET',
      _mine,
      (_) => okResponse([for (final row in rows) row.toJson()]),
    );
    backend.on('GET', '/api/budgets', (_) => okResponse([]));
    backend.on('GET', '/api/categories', (_) => okResponse([]));
  });

  Future<void> pumpLedger(WidgetTester tester, {Key? key}) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAmountVisibility(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: LedgerPage(key: key),
        ),
        settings: FakeSettingsRepository()..amountsHidden = false,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choosePeriod(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(StatsHeaderBand.periodMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> step(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// The three pills of the header band must show the income, the spending (savings left out) and the rest of the
  /// rows [inPeriod] keeps.
  void expectPills(bool Function(DateTime date) inPeriod) {
    final kept = rows.where((r) => inPeriod(r.date));
    final income = kept
        .where((r) => !r.isExpense)
        .fold(0.0, (s, r) => s + r.amount);
    final expense = kept
        .where((r) => r.isExpense && !r.isSavings)
        .fold(0.0, (s, r) => s + r.amount);
    String fmt(double v) => CurrencyHelper.formatCompactVND(v, loc);
    expect(find.text(loc.statsIncome(fmt(income))), findsOneWidget);
    expect(find.text(loc.statsExpense(fmt(expense))), findsOneWidget);
    expect(find.text(loc.statsLeft(fmt(income - expense))), findsOneWidget);
  }

  bool sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  DateTime weekStartOf(DateTime d) => DateTime(
    d.year,
    d.month,
    d.day,
  ).subtract(Duration(days: d.weekday - DateTime.monday));

  bool sameWeek(DateTime a, DateTime b) => weekStartOf(a) == weekStartOf(b);

  testWidgets('the month pills count income and spending, not the savings', (
    tester,
  ) async {
    await pumpLedger(tester);
    expectPills((d) => sameMonth(d, today));
    // 100000 spent, 2000000 earned; the 500000 moved into savings is in the list but not in the spending.
    expect(find.text('Gửi tiết kiệm nay'), findsOneWidget);
  });

  testWidgets('week, year and month steps recompute the pills each time', (
    tester,
  ) async {
    await pumpLedger(tester);

    await choosePeriod(tester, 'Tuần');
    expectPills((d) => sameWeek(d, today));
    expect(find.text('Bữa trưa nay'), findsOneWidget);

    await step(tester, StatsHeaderBand.previousKey);
    expectPills((d) => sameWeek(d, lastWeek));
    expect(find.text('Bữa trưa nay'), findsNothing);
    expect(find.text('Bữa trưa tuần trước'), findsOneWidget);

    await step(tester, StatsHeaderBand.nextKey);
    expectPills((d) => sameWeek(d, today));

    await choosePeriod(tester, 'Năm');
    expectPills((d) => d.year == today.year);

    await step(tester, StatsHeaderBand.previousKey);
    expectPills((d) => d.year == lastYear.year);
    expect(find.text('Thưởng năm ngoái'), findsOneWidget);
    expect(find.text('Bữa trưa nay'), findsNothing);

    await choosePeriod(tester, 'Tháng');
    expectPills((d) => sameMonth(d, DateTime(lastYear.year, today.month)));

    await step(tester, StatsHeaderBand.nextKey);
    expectPills((d) => sameMonth(d, DateTime(lastYear.year, today.month + 1)));
  });

  testWidgets(
    'the date sheet moves the pills and the list to the picked month',
    (tester) async {
      await pumpLedger(tester);
      await tester.tap(find.text('Tháng ${now.month}/${now.year}'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day-15')));
      await tester.pumpAndSettle();

      expectPills((d) => sameMonth(d, lastMonth));
      expect(find.text('Bữa trưa nay'), findsNothing);
      expect(find.text('Bữa trưa tháng trước'), findsOneWidget);
    },
  );

  testWidgets(
    'the calendar keeps the month pills and lists only the chosen day',
    (tester) async {
      await pumpLedger(tester);
      await choosePeriod(tester, 'Năm');
      expectPills((d) => d.year == today.year);

      // Opening the calendar from a year moves the period to the month.
      await tester.tap(find.text('Lịch'));
      await tester.pumpAndSettle();
      expectPills((d) => sameMonth(d, today));
      expect(find.text('Bữa trưa nay'), findsOneWidget);

      // Another day of the month: the pills stay, the list has no row for it.
      final otherDay = today.day == 1 ? 2 : 1;
      await tester.tap(find.byKey(StatsCalendarCard.dayKey(otherDay)));
      await tester.pumpAndSettle();
      expectPills((d) => sameMonth(d, today));
      expect(find.text('Bữa trưa nay'), findsNothing);

      await tester.tap(find.byKey(StatsCalendarCard.dayKey(today.day)));
      await tester.pumpAndSettle();
      expect(find.text('Bữa trưa nay'), findsOneWidget);
    },
  );

  testWidgets('a search narrows the list of the period shown after a step', (
    tester,
  ) async {
    await pumpLedger(tester);
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bữa trưa');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Bữa trưa nay'), findsOneWidget);
    expect(find.text('Lương nay'), findsNothing);

    await step(tester, StatsHeaderBand.previousKey);
    expect(find.text('Bữa trưa nay'), findsNothing);
    expect(find.text('Bữa trưa tháng trước'), findsOneWidget);
    // The pills measure the whole period, whatever the search.
    expectPills((d) => sameMonth(d, lastMonth));
  });

  testWidgets('a reload after a write recomputes the pills of the period', (
    tester,
  ) async {
    await pumpLedger(tester);
    expectPills((d) => sameMonth(d, today));

    rows.add(_Row(8, 'Bữa tối nay', 250000, today));
    rows.removeWhere((r) => r.id == 2);
    RemoteApiHelper.instance.dataChangedNotifier.value++;
    await tester.pumpAndSettle();

    expect(find.text('Bữa tối nay'), findsOneWidget);
    expect(find.text('Lương nay'), findsNothing);
    expectPills((d) => sameMonth(d, today));
  });

  testWidgets(
    'showTransaction moves the period to the date of the transaction',
    (tester) async {
      final key = GlobalKey<LedgerPageState>();
      await pumpLedger(tester, key: key);

      key.currentState!.showTransaction(7);
      await tester.pumpAndSettle();

      // The detail page is on top: the period behind it already moved.
      expect(
        find.text(
          'Tháng ${lastYear.month}/${lastYear.year}',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expectPills((d) => sameMonth(d, lastYear));
    },
  );
}
