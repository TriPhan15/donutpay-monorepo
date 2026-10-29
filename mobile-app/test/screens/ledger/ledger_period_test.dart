import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/ledger_page.dart';
import 'package:finance_ai_app/services/budget_alert_tracker.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

const String _mine = '/api/transactions/mine';
const String _checkout = '/api/transactions/checkout';
const ValueKey<String> _todayKey = ValueKey('ledger-today');

/// Dio hands a request from one step to the next with zero-length timers, which only fire when the fake clock moves.
const Duration _requestStep = Duration(milliseconds: 100);

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
  final year = now.year;

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
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
        _serverRow(2, 'Đầu năm', DateTime(year, 1, 1, 9)),
        _serverRow(3, 'Cuối năm', DateTime(year, 12, 31, 9)),
        _serverRow(4, 'Năm ngoái', DateTime(year - 1, 6, 1, 9)),
      ]),
    );
    backend.on('GET', '/api/budgets', (_) => okResponse([]));
    backend.on('GET', '/api/categories', (_) => okResponse(_serverCategories));
  });

  Future<void> pumpLedger(WidgetTester tester) async {
    // Tall, so that every row is built without scrolling, and wide, because the test font is much wider than a real one.
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('vi'),
        home: LedgerPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choosePeriod(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButton<LedgerPeriod>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapIcon(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the year mode lists and charts the whole year, month by month, and steps by year',
    (tester) async {
      await pumpLedger(tester);
      await choosePeriod(tester, 'Năm');

      expect(find.text('Năm $year'), findsOneWidget);
      expect(find.text('Hôm nay ăn trưa'), findsOneWidget);
      expect(find.text('Đầu năm'), findsOneWidget);
      expect(find.text('Cuối năm'), findsOneWidget);
      expect(find.text('Năm ngoái'), findsNothing);

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups, hasLength(12));
      expect(find.text('Th1'), findsOneWidget);
      expect(find.text('Th12'), findsOneWidget);

      await tapIcon(tester, Icons.chevron_left_rounded);

      expect(find.text('Năm ${year - 1}'), findsOneWidget);
      expect(find.text('Năm ngoái'), findsOneWidget);
      expect(find.text('Đầu năm'), findsNothing);
    },
  );

  testWidgets(
    'the Today button shows only away from the period of today and brings it back in one tap',
    (tester) async {
      await pumpLedger(tester);
      expect(find.byKey(_todayKey), findsNothing);

      await tapIcon(tester, Icons.chevron_left_rounded);
      await tapIcon(tester, Icons.chevron_left_rounded);
      expect(find.byKey(_todayKey), findsOneWidget);
      expect(find.text('Hôm nay ăn trưa'), findsNothing);

      await tester.tap(find.byKey(_todayKey));
      await tester.pumpAndSettle();

      expect(find.byKey(_todayKey), findsNothing);
      expect(find.text('Hôm nay ăn trưa'), findsOneWidget);
    },
  );

  testWidgets('the Today button works in the year and the week mode too', (
    tester,
  ) async {
    await pumpLedger(tester);

    await choosePeriod(tester, 'Năm');
    await tapIcon(tester, Icons.chevron_right_rounded);
    expect(find.text('Năm ${year + 1}'), findsOneWidget);
    await tester.tap(find.byKey(_todayKey));
    await tester.pumpAndSettle();
    expect(find.text('Năm $year'), findsOneWidget);
    expect(find.byKey(_todayKey), findsNothing);

    await choosePeriod(tester, 'Tuần');
    expect(find.byKey(_todayKey), findsNothing);
    await tapIcon(tester, Icons.chevron_left_rounded);
    expect(find.byKey(_todayKey), findsOneWidget);
    await tester.tap(find.byKey(_todayKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_todayKey), findsNothing);
  });

  testWidgets(
    'after adding a transaction the Ledger moves to the period that contains it',
    (tester) async {
      backend.on('POST', _checkout, (_) => okResponse({'transactionId': 9}));
      await pumpLedger(tester);
      await choosePeriod(tester, 'Năm');
      await tapIcon(tester, Icons.chevron_left_rounded);
      await tapIcon(tester, Icons.chevron_left_rounded);
      expect(find.text('Năm ${year - 2}'), findsOneWidget);

      await tapIcon(tester, Icons.add_box_rounded);
      // The form opens on today, whatever period the Ledger shows.
      await tester.enterText(find.byType(TextField).at(0), '45000');
      await tester.tap(find.text('Lưu giao dịch'));
      await tester.pump(_requestStep);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      expect(
        backend.requests.where(
          (r) => r.method == 'POST' && r.path == _checkout,
        ),
        hasLength(1),
      );
      expect(find.text('Năm $year'), findsOneWidget);
      expect(find.byKey(_todayKey), findsNothing);
    },
  );
}
