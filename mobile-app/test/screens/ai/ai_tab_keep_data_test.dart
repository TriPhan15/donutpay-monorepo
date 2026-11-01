import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ai/ai_tab_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

const String _transactionsPath = '/api/transactions/mine';
const String _savingsPath = '/api/savings';
const int _serverError = 500;
const double _tallHeight = 6000;
const double _phoneWidth = 400;

final DateTime _now = DateTime.now();

Map<String, Object?> _tx(
  int id, {
  required num amount,
  bool isExpense = true,
  String category = 'Ăn uống',
}) => {
  'id': id,
  'title': 'Giao dịch $id',
  'amount': amount,
  'date': DateTime(_now.year, _now.month, _now.day, 12).toIso8601String(),
  'category': category,
  'isExpense': isExpense,
};

/// The AI tab when a load fails: what the user was looking at stays, with a notice and a way to try again.
void main() {
  final backend = FakeBackend();
  final loc = lookupAppLocalizations(const Locale('vi'));

  void answerTransactions() => backend.on(
    'GET',
    _transactionsPath,
    (_) => okResponse([
      _tx(1, amount: 450000),
      _tx(2, amount: 9000000, isExpense: false, category: 'Thu nhập'),
    ]),
  );
  void failTransactions() => backend.on(
    'GET',
    _transactionsPath,
    (_) => jsonResponse(_serverError, {'code': _serverError, 'message': 'x'}),
  );
  void answerSavings() =>
      backend.on('GET', _savingsPath, (_) => okResponse([]));
  void failSavings() => backend.on(
    'GET',
    _savingsPath,
    (_) => jsonResponse(_serverError, {'code': _serverError, 'message': 'x'}),
  );

  Future<void> openTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(_phoneWidth, _tallHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: const AITabPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pullToRefresh(WidgetTester tester) async {
    final state = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    unawaited(state.show());
    await tester.pumpAndSettle();
  }

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});

    backend.reset();
    answerTransactions();
    answerSavings();
    backend.on(
      'POST',
      '/spade/analyze',
      (_) => jsonResponse(200, {
        'status': 'NOT_ENOUGH_DATA',
        'patterns': [],
        'rules': [],
        'habits': [],
        'meta': {'weeksWithData': 1, 'minWeeks': 8},
      }),
    );
  });

  testWidgets('a failed pull to refresh keeps the data and offers a retry', (
    tester,
  ) async {
    await openTab(tester);
    expect(find.text(loc.aiHighlightsTitle), findsOneWidget);
    expect(find.text(loc.aiLoadFailedNotice), findsNothing);

    failTransactions();
    await pullToRefresh(tester);

    expect(find.text(loc.aiNoData), findsNothing);
    expect(find.text(loc.aiHighlightsTitle), findsOneWidget);
    expect(find.text(loc.aiLoadFailedNotice), findsOneWidget);
    expect(find.text(loc.commonRetry), findsOneWidget);

    answerTransactions();
    await tester.tap(find.text(loc.commonRetry));
    await tester.pumpAndSettle();

    expect(find.text(loc.aiLoadFailedNotice), findsNothing);
    expect(find.text(loc.aiHighlightsTitle), findsOneWidget);
  });

  testWidgets('a failed savings load keeps the cards and shows the notice', (
    tester,
  ) async {
    await openTab(tester);

    failSavings();
    await pullToRefresh(tester);

    expect(find.text(loc.aiHighlightsTitle), findsOneWidget);
    expect(find.text(loc.aiLoadFailedNotice), findsOneWidget);
  });

  testWidgets('a failed first load is an error with a retry, not "no data"', (
    tester,
  ) async {
    failTransactions();
    await openTab(tester);

    expect(find.text(loc.aiNoData), findsNothing);
    expect(find.text(loc.aiLoadFailedTitle), findsOneWidget);
    expect(find.text(loc.errorServer), findsOneWidget);

    answerTransactions();
    await tester.tap(find.text(loc.commonRetry));
    await tester.pumpAndSettle();

    expect(find.text(loc.aiLoadFailedTitle), findsNothing);
    expect(find.text(loc.aiHighlightsTitle), findsOneWidget);
  });
}
