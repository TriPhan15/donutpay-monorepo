import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/dashboard/dashboard_page.dart';
import 'package:finance_ai_app/screens/dashboard/widgets/home_header_band.dart';
import 'package:finance_ai_app/screens/ledger/ledger_page.dart';
import 'package:finance_ai_app/services/budget_alert_tracker.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/vnd.dart';

const String _mine = '/api/transactions/mine';
const String _checkout = '/api/transactions/checkout';
const String _balanceLabel = 'Số dư';
const String _warningTitle = 'Sắp chạm hạn mức ngân sách';

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

Map<String, Object?> _tx(
  num amount, {
  required int id,
  bool isExpense = true,
  String? source,
}) => {
  'id': id,
  'title': 'Giao dịch $id',
  'amount': amount,
  'date': DateTime.now().toIso8601String(),
  'category': 'Ăn uống',
  'isExpense': isExpense,
  'source': ?source,
};

Map<String, Object?> _monthlyBudget(num amount) {
  final now = DateTime.now();
  return {
    'id': 1,
    'categoryId': 10,
    'categoryName': 'Ăn uống',
    'amount': amount,
    'periodType': 'MONTH',
    'startDate': _ymd(DateTime(now.year, now.month, 1)),
    'endDate': _ymd(DateTime(now.year, now.month + 1, 0)),
  };
}

/// The home screen and the Ledger kept alive side by side, as in MainScaffold; the home screen is the one on top.
Widget _tabs() => withAmountVisibility(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    home: const Scaffold(
      body: IndexedStack(index: 0, children: [DashboardPage(), LedgerPage()]),
    ),
  ),
);

void main() {
  final backend = FakeBackend();
  var transactions = <Map<String, Object?>>[];
  var budgets = <Map<String, Object?>>[];
  num walletBalance = 0;

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    // See budget_display_test.dart: SharedPreferences must be reset after the session is written.
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
    BudgetAlertTracker.instance.resetMemory();
    BudgetAlertPresenter.resetQueue();

    backend.reset();
    transactions = [];
    budgets = [];
    walletBalance = 0;
    backend.on(
      'GET',
      '/api/users/me',
      (_) => okResponse({
        'id': 1,
        'email': 'an@example.com',
        'walletBalance': walletBalance,
      }),
    );
    backend.on('GET', _mine, (_) => okResponse(transactions));
    backend.on('GET', '/api/budgets', (_) => okResponse(budgets));
    backend.on('GET', '/api/notifications/unread-count', (_) => okResponse(0));
    backend.on('POST', _checkout, (_) => okResponse({'transactionId': 3}));
  });

  Future<void> pump(WidgetTester tester, Widget app) async {
    // Tall and wide: the test font is much wider than a real one and the rows of the home screen would overflow.
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    // The balance is hidden when the home screen opens: the eye shows it.
    final eye = find.byIcon(Icons.visibility_off_rounded);
    if (eye.evaluate().isNotEmpty) {
      await tester.tap(eye.first);
      await tester.pumpAndSettle();
    }
  }

  /// A write made elsewhere in the app (the Ledger, the receipt form ...): the server has [after] once it is done.
  Future<void> writeElsewhere(
    WidgetTester tester,
    List<Map<String, Object?>> after,
  ) async {
    transactions = after;
    // Dio moves a request on with zero-length timers, which fire only when the fake clock of the test moves.
    final write = RemoteApiHelper.instance.addTransaction({'amount': 1});
    await tester.pump(const Duration(milliseconds: 100));
    await write;
    // addTransaction announces nothing: AppRepository does it once the outbox row is flagged.
    RemoteApiHelper.instance.notifyDataChanged();
    await tester.pumpAndSettle();
  }

  int listRequests() => backend.calls.where((c) => c == 'GET $_mine').length;

  testWidgets(
    'the balance is called "Số dư" and is the one the server keeps, below zero too',
    (tester) async {
      walletBalance = -200000;
      transactions = [_tx(100000, id: 1, isExpense: false), _tx(300000, id: 2)];

      await pump(tester, _tabs());

      expect(find.text(_balanceLabel), findsOneWidget);
      expect(find.text('Tổng tài sản hiện tại'), findsNothing);
      expect(find.text(vnd(-200000)), findsOneWidget);
    },
  );

  testWidgets('the balance card shows the server balance and the pending note', (
    tester,
  ) async {
    walletBalance = 750000;
    transactions = [_tx(1000000, id: 1, isExpense: false)];
    // A purchase made offline: on this device only, so the balance of the server does not include it.
    final store = FakeLocalStore();
    AppRepository.instance.localStore = store;
    addTearDown(() => AppRepository.instance.localStore = FakeLocalStore());
    await store.insertTransaction(
      TransactionModel.draft(
        title: 'Cà phê',
        category: 'Ăn uống',
        amount: 200000,
        date: DateTime.now(),
        isExpense: true,
      ).withSyncStatus(SyncStatus.pending),
      1,
    );

    await pump(tester, _tabs());

    expect(find.text(vnd(750000)), findsOneWidget);
    expect(
      find.text('Chưa tính ${vnd(-200000)} của giao dịch đang chờ gửi'),
      findsOneWidget,
    );
    // The month totals count the purchase waiting on the device too, in the compact form of the band.
    expect(find.text('Thu 1 tr'), findsOneWidget);
    expect(find.text('Chi 200k'), findsOneWidget);
  });

  testWidgets(
    'the month totals leave out the refund of a savings goal and the transfers of a linked wallet',
    (tester) async {
      transactions = [
        _tx(1000000, id: 1, isExpense: false),
        _tx(200000, id: 2),
        _tx(500000, id: 3, isExpense: false, source: 'GOAL_REFUND'),
        _tx(5000000, id: 4, isExpense: false, source: 'WALLET_TRANSFER'),
        _tx(3000000, id: 5, source: 'WALLET_TRANSFER'),
      ];

      await pump(tester, _tabs());

      expect(find.text('Thu 1 tr'), findsOneWidget);
      expect(find.text('Chi 200k'), findsOneWidget);
    },
  );

  testWidgets('no pending note when nothing waits on the device', (
    tester,
  ) async {
    walletBalance = 750000;
    await pump(tester, _tabs());

    expect(find.textContaining('của giao dịch đang chờ gửi'), findsNothing);
  });

  testWidgets(
    'a write on another tab reloads the home screen and the Ledger kept behind it',
    (tester) async {
      walletBalance = 100000;
      transactions = [_tx(100000, id: 1, isExpense: false)];
      await pump(tester, _tabs());
      expect(find.text(vnd(100000)), findsWidgets);
      expect(find.text('Giao dịch 2', skipOffstage: false), findsNothing);

      walletBalance = 60000;
      await writeElsewhere(tester, [
        _tx(100000, id: 1, isExpense: false),
        _tx(40000, id: 2),
      ]);

      expect(find.text(vnd(60000)), findsOneWidget);
      expect(
        find.text('Giao dịch 2', skipOffstage: false),
        findsWidgets,
        reason: 'the Ledger in the IndexedStack has the new transaction too',
      );
    },
  );

  testWidgets(
    'after a write the budget band moves and the 80% alert shows without a manual refresh',
    (tester) async {
      budgets = [_monthlyBudget(1000000)];
      transactions = [_tx(400000, id: 1)];
      await pump(tester, _tabs());
      expect(find.text('40%'), findsOneWidget);
      expect(find.text(_warningTitle), findsNothing);

      await writeElsewhere(tester, [_tx(400000, id: 1), _tx(450000, id: 2)]);

      expect(find.text(_warningTitle), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(find.text('85%'), findsOneWidget);
    },
  );

  testWidgets('a reload with data on screen keeps the page and shows no spinner', (
    tester,
  ) async {
    walletBalance = 100000;
    await pump(tester, _tabs());
    // The home screen and the Ledger both ask: each gets its own answer once the test lets them through.
    final gate = Completer<void>();
    backend.on(
      'GET',
      _mine,
      (_) => gate.future.then((_) => okResponse(<Object>[])),
    );

    RemoteApiHelper.instance.notifyDataChanged();
    await tester.pump(const Duration(milliseconds: 100));

    // The band stays: the page is not swapped for the spinner of a first load.
    expect(find.byType(HomeHeaderBand), findsOneWidget);
    expect(find.text(vnd(100000)), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a failed first load offers retry, and retry loads', (
    tester,
  ) async {
    walletBalance = 100000;
    backend.on('GET', _mine, (_) => jsonResponse(500, {'code': 500}));
    await tester.pumpWidget(_tabs());
    await tester.pumpAndSettle();

    expect(find.text('Chưa tải được trang chủ'), findsOneWidget);
    expect(find.text(_balanceLabel), findsNothing);
    expect(find.byType(Dialog), findsNothing);

    backend.on('GET', _mine, (_) => okResponse(transactions));
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa tải được trang chủ'), findsNothing);
    expect(find.text(_balanceLabel), findsOneWidget);
  });

  testWidgets('a failed reload keeps the old data without a dialog', (
    tester,
  ) async {
    walletBalance = 100000;
    await pump(tester, _tabs());
    backend.on('GET', _mine, (_) => jsonResponse(500, {'code': 500}));

    RemoteApiHelper.instance.notifyDataChanged();
    await tester.pumpAndSettle();

    expect(find.text(vnd(100000)), findsOneWidget);
    expect(find.text('Chưa tải được trang chủ'), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('budgets failing on a reload keep the band that was shown', (
    tester,
  ) async {
    budgets = [_monthlyBudget(1000000)];
    transactions = [_tx(400000, id: 1)];
    await pump(tester, _tabs());
    expect(find.text('40%'), findsOneWidget);

    backend.on('GET', '/api/budgets', (_) => jsonResponse(500, {'code': 500}));
    RemoteApiHelper.instance.notifyDataChanged();
    await tester.pumpAndSettle();

    expect(find.text('40%'), findsOneWidget);
    expect(find.text('Chưa tải được ngân sách'), findsNothing);
  });

  testWidgets('a page that is gone stops listening', (tester) async {
    await pump(tester, _tabs());
    await tester.pumpWidget(const SizedBox());
    final before = listRequests();

    await writeElsewhere(tester, []);

    expect(listRequests(), before);
    expect(tester.takeException(), isNull);
  });
}
