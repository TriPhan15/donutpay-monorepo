import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
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

final List<Map<String, Object?>> _serverCategories = [
  {'id': 10, 'name': 'Ăn uống', 'type': 'EXPENSE'},
  {'id': 6, 'name': 'Thu nhập', 'type': 'INCOME'},
];

/// A transaction the way core-backend sends it.
Map<String, Object?> _serverRow(int id, String title, DateTime date) => {
  'id': id,
  'title': title,
  'amount': 45000,
  'date': date.toIso8601String(),
  'category': 'Ăn uống',
  'isExpense': true,
};

void main() {
  final backend = FakeBackend();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Another day of this month, so that the calendar has two days with rows.
  final otherDay = DateTime(now.year, now.month, now.day == 1 ? 2 : 1, 9);
  String dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

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

    AppRepository.instance.localStore = FakeLocalStore();
    backend.reset();
    backend.on(
      'GET',
      _mine,
      (_) => okResponse([
        _serverRow(1, 'Hôm nay ăn trưa', now),
        _serverRow(2, 'Ngày khác', otherDay),
      ]),
    );
    backend.on('GET', '/api/budgets', (_) => okResponse([]));
    backend.on('GET', '/api/categories', (_) => okResponse(_serverCategories));
  });

  Future<void> pumpLedger(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAmountVisibility(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('vi'),
          home: LedgerPage(),
        ),
        settings: FakeSettingsRepository()..amountsHidden = false,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'switching to Lịch from Tuần moves the period to the month and selects today',
    (tester) async {
      await pumpLedger(tester);
      await tap(tester, find.byKey(StatsHeaderBand.periodMenuKey));
      await tap(tester, find.text('Tuần').last);

      await tap(tester, find.text('Lịch'));

      expect(find.text('Tháng ${now.month}/${now.year}'), findsOneWidget);
      expect(find.byType(StatsCalendarCard), findsOneWidget);
      expect(find.text('Giao dịch ngày ${dm(today)}'), findsOneWidget);
      expect(find.text('Hôm nay ăn trưa'), findsOneWidget);
      expect(find.text('Ngày khác'), findsNothing);
    },
  );

  testWidgets('tapping a day lists only that day', (tester) async {
    await pumpLedger(tester);
    await tap(tester, find.text('Lịch'));

    await tap(tester, find.byKey(StatsCalendarCard.dayKey(otherDay.day)));

    expect(find.text('Giao dịch ngày ${dm(otherDay)}'), findsOneWidget);
    expect(find.text('Ngày khác'), findsOneWidget);
    expect(find.text('Hôm nay ăn trưa'), findsNothing);
    expect(find.text('Tổng chi 45.000 đ'), findsOneWidget);
  });

  testWidgets(
    '‹ in Lịch selects day 1 of a past month, today in the current one',
    (tester) async {
      await pumpLedger(tester);
      await tap(tester, find.text('Lịch'));

      await tap(tester, find.byKey(StatsHeaderBand.previousKey));
      final previous = DateTime(now.year, now.month - 1, 1);
      expect(find.text('Giao dịch ngày ${dm(previous)}'), findsOneWidget);

      await tap(tester, find.byKey(StatsHeaderBand.nextKey));
      expect(find.text('Giao dịch ngày ${dm(today)}'), findsOneWidget);
    },
  );

  testWidgets('+ Thêm opens the add form', (tester) async {
    await pumpLedger(tester);
    await tap(tester, find.text('Lịch'));
    await tap(tester, find.text('+ Thêm'));
    expect(find.text('Thêm giao dịch chi'), findsOneWidget);
  });

  testWidgets(
    'a filter that matches nothing shows the no-match state with Đặt lại',
    (tester) async {
      await pumpLedger(tester);
      await tap(tester, find.byKey(StatsHeaderBand.filterKey));
      await tap(tester, find.text('>500k'));
      await tap(tester, find.text('Xem 0 giao dịch'));

      expect(find.text('Không có giao dịch khớp bộ lọc'), findsOneWidget);
      expect(find.text('Hôm nay ăn trưa'), findsNothing);
      expect(
        find.text('Chi 90k'),
        findsOneWidget,
        reason: 'the totals ignore the filter',
      );

      await tap(tester, find.text('Đặt lại'));
      expect(find.text('Hôm nay ăn trưa'), findsOneWidget);
      expect(find.text('Không có giao dịch khớp bộ lọc'), findsNothing);
    },
  );

  testWidgets('in Lịch the filter counts the chosen day only, like the list', (
    tester,
  ) async {
    await pumpLedger(tester);
    await tap(tester, find.text('Lịch'));

    await tap(tester, find.byKey(StatsHeaderBand.filterKey));

    expect(find.text('Xem 1 giao dịch'), findsOneWidget);
    expect(find.text('Xem 2 giao dịch'), findsNothing);
  });

  testWidgets(
    'in Danh mục an active filter or search says that it narrows the list of the other views',
    (tester) async {
      const hint =
          'Lọc và tìm kiếm chỉ áp dụng cho danh sách giao dịch ở Biểu đồ và Lịch.';
      await pumpLedger(tester);
      await tap(tester, find.text('Danh mục'));
      expect(find.text(hint), findsNothing);

      await tap(tester, find.byKey(StatsHeaderBand.filterKey));
      await tap(tester, find.text('>500k'));
      await tap(tester, find.text('Xem 0 giao dịch'));
      expect(find.text(hint), findsOneWidget);

      await tap(tester, find.byKey(StatsHeaderBand.filterKey));
      await tap(tester, find.text('Đặt lại'));
      await tap(tester, find.text('Xem 2 giao dịch'));
      expect(find.text(hint), findsNothing);

      await tap(tester, find.byKey(StatsHeaderBand.searchKey));
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();
      expect(find.text(hint), findsOneWidget);
    },
  );
}
