import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/dashboard/dashboard_page.dart';
import 'package:finance_ai_app/screens/ledger/ledger_page.dart';
import 'package:finance_ai_app/screens/ledger/transaction_detail_page.dart';
import 'package:finance_ai_app/services/budget_alert_tracker.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_status_badge.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

const String _processingLabel = 'Đang xử lý';
const String _successLabel = 'Hoàn tất';
const String _failedLabel = 'Lỗi · cần xác nhận lại';
const String _editLabel = 'Sửa giao dịch';
const String _deleteLabel = 'Xóa';

/// Amounts as the Vietnamese screens write them.
String _money(num amount) => CurrencyHelper.formatVND(
  amount.toDouble(),
  AppLanguage.vietnamese.localizations,
  showSign: false,
);

final List<Map<String, Object?>> _serverCategories = [
  {'id': 10, 'name': 'Ăn uống', 'type': 'EXPENSE'},
  {'id': 11, 'name': 'Di chuyển', 'type': 'EXPENSE'},
  {'id': 6, 'name': 'Thu nhập', 'type': 'INCOME'},
];

/// A transaction the way core-backend sends it; [receiptStatus] is left out for a transaction without a receipt.
Map<String, Object?> _tx(int id, {num amount = 45000, String? receiptStatus}) =>
    {
      'id': id,
      'title': 'Giao dịch $id',
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
      'category': 'Ăn uống',
      'isExpense': true,
      'receiptStatus': ?receiptStatus,
    };

void main() {
  final backend = FakeBackend();
  var transactions = <Map<String, Object?>>[];

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    // The lists also read the transactions waiting to be sent; the fake keeps the test away from a real database.
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body, which runs in fake async, so the
    // store is reset after the session is written and the body starts from scratch (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
    BudgetAlertTracker.instance.resetMemory();
    BudgetAlertPresenter.resetQueue();

    // The category lists are static, so a test that loads them would otherwise feed the next one.
    TransactionCategories.expenseSelectable.clear();
    TransactionCategories.incomeSelectable.clear();

    backend.reset();
    transactions = [];
    backend.on(
      'GET',
      '/api/users/me',
      (_) => okResponse({'id': 1, 'email': 'an@example.com'}),
    );
    backend.on(
      'GET',
      '/api/transactions/mine',
      (_) => okResponse(transactions),
    );
    backend.on('GET', '/api/budgets', (_) => okResponse([]));
    backend.on('GET', '/api/categories', (_) => okResponse(_serverCategories));
    // The home screen also asks for the number on its notification bell.
    backend.on('GET', '/api/notifications/unread-count', (_) => okResponse(0));
  });

  Future<void> pump(WidgetTester tester, Widget app) async {
    // Tall, so that every row is built without scrolling, and wide, because the test font is much wider than a real one.
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(withAmountVisibility(app));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('Ledger', () {
    const app = MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('vi'),
      home: LedgerPage(),
    );

    Finder rowOf(int id) => find.ancestor(
      of: find.text('Giao dịch $id'),
      matching: find.byType(InkWell),
    );

    Finder inRow(int id, String label) =>
        find.descendant(of: rowOf(id), matching: find.text(label));

    testWidgets(
      'each row shows the state of its receipt, and rows without one show none',
      (tester) async {
        transactions = [
          _tx(1, receiptStatus: 'PENDING'),
          _tx(2, receiptStatus: 'success'),
          _tx(3, receiptStatus: 'FAILED'),
          _tx(4),
          _tx(5, receiptStatus: 'CANCELED'),
        ];

        await pump(tester, app);

        expect(find.byType(ReceiptStatusBadge), findsNWidgets(3));
        expect(inRow(1, _processingLabel), findsOneWidget);
        expect(inRow(2, _successLabel), findsOneWidget);
        expect(inRow(3, _failedLabel), findsOneWidget);
        expect(
          find.descendant(
            of: rowOf(4),
            matching: find.byType(ReceiptStatusBadge),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: rowOf(5),
            matching: find.byType(ReceiptStatusBadge),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a status the server adds later is left out instead of breaking the list',
      (tester) async {
        transactions = [
          _tx(1, receiptStatus: 'SOMETHING_NEW'),
          _tx(2, receiptStatus: 'SUCCESS'),
        ];

        await pump(tester, app);

        expect(find.text('Giao dịch 1'), findsOneWidget);
        expect(find.byType(ReceiptStatusBadge), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the details show the state of the receipt and offer to edit and to delete the transaction',
      (tester) async {
        transactions = [_tx(1, receiptStatus: 'FAILED')];
        await pump(tester, app);

        await tapText(tester, 'Giao dịch 1');

        expect(find.text('Hóa đơn'), findsOneWidget);
        expect(
          find.text(_failedLabel),
          findsOneWidget,
          reason: 'on the details page, the list is behind it',
        );
        expect(find.text(_editLabel), findsOneWidget);
        expect(find.text(_deleteLabel), findsOneWidget);
      },
    );

    testWidgets(
      'the details of a transaction without a receipt have no status row',
      (tester) async {
        transactions = [_tx(1)];
        await pump(tester, app);

        await tapText(tester, 'Giao dịch 1');

        expect(find.text('Hóa đơn'), findsNothing);
        expect(find.byType(ReceiptStatusBadge), findsNothing);
        expect(find.text(_editLabel), findsOneWidget);
      },
    );

    testWidgets(
      'editing from the details PUTs the change, then the ledger shows the new amount',
      (tester) async {
        transactions = [_tx(1, amount: 45000, receiptStatus: 'FAILED')];
        backend.on('PUT', '/api/transactions/1', (_) {
          transactions = [_tx(1, amount: 50000, receiptStatus: 'FAILED')];
          return okResponse(transactions.single);
        });
        await pump(tester, app);
        expect(find.text('-${_money(45000)}'), findsOneWidget);

        await tapText(tester, 'Giao dịch 1');
        await tapText(tester, _editLabel);

        expect(
          find.text('Lưu thay đổi'),
          findsOneWidget,
          reason: 'the edit form is open',
        );
        await tester.enterText(find.byType(TextField).first, '50000');
        // The button follows the amount: one frame before the tap.
        await tester.pump();
        await tapText(tester, 'Lưu thay đổi');
        await tapText(tester, 'Xong');

        final puts = backend.requests.where((r) => r.method == 'PUT').toList();
        expect(puts, hasLength(1));
        expect(puts.single.path, '/api/transactions/1');
        expect(puts.single.data, {'amount': 50000.0});
        expect(
          find.text('Lưu thay đổi'),
          findsNothing,
          reason: 'back on the ledger',
        );
        expect(find.text('-${_money(50000)}'), findsOneWidget);
        expect(find.text('-${_money(45000)}'), findsNothing);
      },
    );

    testWidgets('closing the edit form without saving changes nothing', (
      tester,
    ) async {
      transactions = [_tx(1)];
      await pump(tester, app);
      final requestsBefore = backend.requests.length;

      await tapText(tester, 'Giao dịch 1');
      await tapText(tester, _editLabel);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Lưu thay đổi'), findsNothing);
      expect(find.byType(TransactionDetailPage), findsOneWidget);
      await tester.tap(find.byKey(TransactionDetailPage.backKey));
      await tester.pumpAndSettle();

      expect(find.text('-${_money(45000)}'), findsOneWidget);
      expect(backend.requests.where((r) => r.method == 'PUT'), isEmpty);
      expect(
        backend.requests
            .skip(requestsBefore)
            .map((r) => '${r.method} ${r.path}'),
        ['GET /api/categories'],
        reason:
            'only the category list is fetched: no reload after a form that saved nothing',
      );
    });
  });

  group('Dashboard', () {
    testWidgets('the recent transactions carry the badge of their receipt', (
      tester,
    ) async {
      transactions = [_tx(1, receiptStatus: 'SUCCESS'), _tx(2)];

      await pump(
        tester,
        // The bell of the home screen reads its tooltip from the app's localizations.
        withAmountVisibility(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('vi'),
            home: Scaffold(body: DashboardPage()),
          ),
        ),
      );

      expect(find.text('Giao dịch 1'), findsOneWidget);
      expect(find.text('Giao dịch 2'), findsOneWidget);
      expect(find.byType(ReceiptStatusBadge), findsOneWidget);
      expect(find.text(_successLabel), findsOneWidget);
    });
  });

  testWidgets(
    'in English the Ledger, its rows and the details sheet speak English, with default categories translated',
    (tester) async {
      transactions = [_tx(1, receiptStatus: 'FAILED')];
      await pump(
        tester,
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: LedgerPage(),
        ),
      );

      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Food & drinks'), findsOneWidget);
      expect(find.textContaining('Ăn uống'), findsNothing);
      expect(find.text('-45,000 đ'), findsOneWidget);

      await tapText(tester, 'Giao dịch 1');

      expect(find.text('Receipt'), findsOneWidget);
      expect(find.text('Edit transaction'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    },
  );
}
