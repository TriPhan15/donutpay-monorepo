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

const String _editLabel = 'Sửa giao dịch';
const String _notFound =
    'Không tìm thấy giao dịch của thông báo này, có thể nó đã bị xóa.';

Map<String, Object?> _tx(int id, DateTime date) => {
  'id': id,
  'title': 'Giao dịch $id',
  'amount': 45000,
  'date': date.toIso8601String(),
  'category': 'Ăn uống',
  'isExpense': true,
};

/// LedgerPage.showTransaction: where a tapped transaction notification leads (MainScaffold switches to the Ledger tab).
void main() {
  final backend = FakeBackend();
  var transactions = <Map<String, Object?>>[];

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    AppRepository.instance.localStore = FakeLocalStore();
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

    backend.reset();
    transactions = [];
    backend.on(
      'GET',
      '/api/transactions/mine',
      (_) => okResponse(transactions),
    );
    backend.on('GET', '/api/budgets', (_) => okResponse([]));
  });

  final ledgerKey = GlobalKey<LedgerPageState>();

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: LedgerPage(key: ledgerKey),
      ),
    );
    await tester.pumpAndSettle();
  }

  int listLoads() =>
      backend.calls.where((c) => c == 'GET /api/transactions/mine').length;

  testWidgets(
    'opens the detail sheet of a listed transaction, even one outside the shown period, without reloading',
    (tester) async {
      final lastYear = DateTime.now().subtract(const Duration(days: 400));
      transactions = [_tx(1, DateTime.now()), _tx(2, lastYear)];
      await pump(tester);
      expect(find.text('Giao dịch 2'), findsNothing, reason: 'other period');
      final loads = listLoads();

      ledgerKey.currentState!.showTransaction(2);
      await tester.pumpAndSettle();

      expect(find.text(_editLabel), findsOneWidget);
      expect(find.text('Giao dịch 2'), findsWidgets);
      expect(listLoads(), loads);
    },
  );

  testWidgets(
    'a transaction created after the last load is loaded first, then opened',
    (tester) async {
      await pump(tester);
      transactions = [_tx(9, DateTime.now())];

      ledgerKey.currentState!.showTransaction(9);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text(_editLabel), findsOneWidget);
    },
  );

  testWidgets(
    'a transaction that no longer exists is reported, nothing opens',
    (tester) async {
      transactions = [_tx(1, DateTime.now())];
      await pump(tester);

      ledgerKey.currentState!.showTransaction(404);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text(_notFound), findsOneWidget);
      expect(find.text(_editLabel), findsNothing);
    },
  );
}
