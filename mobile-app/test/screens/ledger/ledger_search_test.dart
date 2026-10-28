import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/ledger_page.dart';
import 'package:finance_ai_app/services/budget_alert_tracker.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';

import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

const String _mine = '/api/transactions/mine';
const String _search = '/api/transactions/search';

/// The debounce of the Ledger is 350 ms: waiting this long fires the search request.
const Duration _pastDebounce = Duration(milliseconds: 400);

/// Dio hands a request from one step to the next with zero-length timers, which only fire when the fake clock moves.
const Duration _requestStep = Duration(milliseconds: 100);

/// Enough steps for a request to go through Dio and its interceptors and come back.
const int _requestSteps = 5;

/// A transaction the way core-backend sends it.
Map<String, Object?> _serverRow(int id, String title) => {
  'id': id,
  'title': title,
  'amount': 45000,
  'date': DateTime.now().toIso8601String(),
  'category': 'Ăn uống',
  'isExpense': true,
};

/// The answer of GET /api/transactions/search for these ids.
ResponseBody _found(List<int> ids) => okResponse({
  'items': [for (final id in ids) _serverRow(id, 'x')],
  'total': ids.length,
  'engine': 'elasticsearch',
});

void main() {
  final backend = FakeBackend();
  late FakeLocalStore store;

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

    store = FakeLocalStore();
    AppRepository.instance.localStore = store;
    backend.reset();
    backend.on(
      'GET',
      _mine,
      (_) => okResponse([
        _serverRow(1, 'Phở Hùng'),
        _serverRow(2, 'Cà phê sáng'),
        _serverRow(3, 'Bún bò'),
      ]),
    );
    backend.on('GET', '/api/budgets', (_) => okResponse([]));
    backend.on('GET', '/api/categories', (_) => okResponse([]));
  });

  Future<void> openSearch(WidgetTester tester) async {
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
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
  }

  /// Types [text] and lets the debounce and the request go by.
  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(_pastDebounce);
    for (var i = 0; i < _requestSteps; i++) {
      await tester.pump(_requestStep);
    }
  }

  List<String> searchQueries() => backend.requests
      .where((r) => r.path == _search)
      .map((r) => r.queryParameters['q'] as String)
      .toList();

  testWidgets('serverIdsShown_evenWhenTitleHasDiacritics', (tester) async {
    backend.on('GET', _search, (_) => _found([1]));
    await openSearch(tester);

    await type(tester, 'pho');

    expect(searchQueries(), ['pho']);
    expect(find.text('Phở Hùng'), findsOneWidget);
    expect(find.text('Cà phê sáng'), findsNothing);
    expect(find.text('Bún bò'), findsNothing);
  });

  testWidgets('localMatchNotInServerSet_staysVisible', (tester) async {
    // The server only adds matches (accents, typos): what the device finds by itself is never hidden.
    backend.on('GET', _search, (_) => _found([1]));
    await openSearch(tester);

    await type(tester, 'bún');

    expect(searchQueries(), ['bún']);
    expect(find.text('Bún bò'), findsOneWidget);
    expect(find.text('Phở Hùng'), findsOneWidget);
    expect(find.text('Cà phê sáng'), findsNothing);
  });

  testWidgets('serverError_fallsBackToLocalFilter', (tester) {
    return withCapturedLogs((logs) async {
      backend.on(
        'GET',
        _search,
        (_) => jsonResponse(500, {'code': 500, 'message': 'boom'}),
      );
      await openSearch(tester);

      await type(tester, 'bún');

      expect(find.text('Bún bò'), findsOneWidget);
      expect(find.text('Phở Hùng'), findsNothing);
      expect(logs.where((l) => l.contains('Lỗi tìm kiếm')), isNotEmpty);
    });
  });

  testWidgets('unsyncedRow_matchedLocally_alongsideServerResults', (
    tester,
  ) async {
    await store.insertTransaction(
      TransactionModel.draft(
        title: 'pho bo',
        category: 'Ăn uống',
        amount: 30000,
        date: DateTime.now(),
        isExpense: true,
      ).withSyncStatus(SyncStatus.pending),
      1,
    );
    backend.on('GET', _search, (_) => _found([1]));
    await openSearch(tester);

    await type(tester, 'pho');

    expect(find.text('Phở Hùng'), findsOneWidget);
    expect(find.text('pho bo'), findsOneWidget);
    expect(find.text('Cà phê sáng'), findsNothing);
  });

  testWidgets('oneCharQuery_doesNotCallServer', (tester) async {
    backend.on('GET', _search, (_) => _found([1]));
    await openSearch(tester);

    await type(tester, 'p');

    expect(searchQueries(), isEmpty);
    expect(find.text('Phở Hùng'), findsOneWidget);
    expect(find.text('Cà phê sáng'), findsOneWidget);
    expect(find.text('Bún bò'), findsNothing);
  });

  testWidgets('staleResponse_ignored', (tester) async {
    final slow = Completer<ResponseBody>();
    backend.on('GET', _search, (options) {
      if (options.queryParameters['q'] == 'ph') return slow.future;
      return _found([1]);
    });
    await openSearch(tester);

    await type(tester, 'ph');
    await type(tester, 'pho');
    expect(searchQueries(), ['ph', 'pho']);
    expect(find.text('Phở Hùng'), findsOneWidget);
    expect(find.text('Cà phê sáng'), findsNothing);

    slow.complete(_found([2]));
    for (var i = 0; i < _requestSteps; i++) {
      await tester.pump(_requestStep);
    }

    expect(find.text('Phở Hùng'), findsOneWidget);
    expect(find.text('Cà phê sáng'), findsNothing);
  });

  testWidgets('serverMatchesOfThePreviousText_goAsSoonAsTheTextChanges', (
    tester,
  ) async {
    final slow = Completer<ResponseBody>();
    backend.on('GET', _search, (options) {
      if (options.queryParameters['q'] == 'phox') return slow.future;
      return _found([1]);
    });
    await openSearch(tester);

    await type(tester, 'pho');
    expect(find.text('Phở Hùng'), findsOneWidget);

    // The answer for "phox" is still on its way: row 1 only matched "pho" on the server.
    await type(tester, 'phox');
    expect(searchQueries(), ['pho', 'phox']);
    expect(find.text('Phở Hùng'), findsNothing);

    slow.complete(_found([2]));
    for (var i = 0; i < _requestSteps; i++) {
      await tester.pump(_requestStep);
    }
    expect(find.text('Phở Hùng'), findsNothing);
    expect(find.text('Cà phê sáng'), findsOneWidget);
  });
}
