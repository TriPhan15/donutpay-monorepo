import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/budget/budget_form_sheet.dart';
import 'package:finance_ai_app/screens/budget/budget_screen.dart';
import 'package:finance_ai_app/screens/budget/widgets/budget_band_summary.dart';
import 'package:finance_ai_app/screens/budget/widgets/budget_group_card.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

/// The app in Vietnamese, the language these texts are written in.
Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('vi'),
  home: home,
);

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// A budget whose period of [periodType] contains [day] (today by default).
Map<String, Object?> _budget({
  int id = 7,
  int? categoryId = 10,
  String? categoryName = 'Ăn uống',
  num amount = 1000000,
  String periodType = BudgetPeriodType.month,
  DateTime? day,
}) {
  final range = BudgetPeriodType.rangeContaining(
    periodType,
    day ?? DateTime.now(),
  );
  return {
    'id': id,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'amount': amount,
    'periodType': periodType,
    'startDate': _ymd(range.start),
    'endDate': _ymd(range.end),
  };
}

Map<String, Object?> _expense(int id, String category, num amount) => {
  'id': id,
  'title': category,
  'amount': amount,
  'date': DateTime.now().toIso8601String(),
  'category': category,
  'isExpense': true,
};

final List<Map<String, Object?>> _serverCategories = [
  {'id': 10, 'name': 'Ăn uống', 'type': 'EXPENSE'},
  {'id': 11, 'name': 'Di chuyển', 'type': 'EXPENSE'},
];

void main() {
  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend.reset();
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    backend.on('GET', '/api/transactions/mine', (_) => okResponse([]));
    backend.on('GET', '/api/categories', (_) => okResponse(_serverCategories));
  });

  tearDown(() async {
    await SessionService.clearSession();
  });

  void serveBudgets(List<Map<String, Object?>> budgets) =>
      backend.on('GET', '/api/budgets', (_) => okResponse(budgets));

  void serveExpenses(List<Map<String, Object?>> expenses) =>
      backend.on('GET', '/api/transactions/mine', (_) => okResponse(expenses));

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const BudgetScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder inGroup(BudgetGroupKind kind, String text) => find.descendant(
    of: find.byWidgetPredicate((w) => w is BudgetGroupCard && w.kind == kind),
    matching: find.text(text),
  );

  int budgetCalls() =>
      backend.calls.where((call) => call == 'GET /api/budgets').length;

  group('listing', () {
    testWidgets(
      'splits the running month budgets into over and within, with the total in the band',
      (tester) async {
        serveBudgets([
          _budget(id: 7, categoryName: 'Ăn uống', amount: 1000000),
          _budget(
            id: 8,
            categoryId: 11,
            categoryName: 'Di chuyển',
            amount: 1000000,
          ),
          _budget(
            id: 9,
            categoryName: 'Ăn uống',
            day: DateTime.now().subtract(const Duration(days: 62)),
          ),
        ]);
        serveExpenses([
          _expense(1, 'Ăn uống', 1200000),
          _expense(2, 'Di chuyển', 300000),
        ]);

        await pumpScreen(tester);

        expect(inGroup(BudgetGroupKind.over, 'Ăn uống'), findsOneWidget);
        expect(inGroup(BudgetGroupKind.within, 'Di chuyển'), findsOneWidget);
        expect(
          find.text('Ăn uống'),
          findsOneWidget,
          reason: 'the past month is not listed',
        );
        expect(find.byType(BudgetBandSummary), findsOneWidget);
        expect(find.text('75%'), findsOneWidget, reason: '1,5 tr of 2 tr');

        for (final request in backend.requests) {
          expect(request.queryParameters, isEmpty);
          expect(request.data, isNull);
        }
      },
    );

    testWidgets('opens on the week when only a week budget runs today', (
      tester,
    ) async {
      serveBudgets([
        _budget(id: 7, periodType: BudgetPeriodType.week),
        _budget(
          id: 8,
          categoryId: 11,
          categoryName: 'Di chuyển',
          day: DateTime.now().subtract(const Duration(days: 62)),
        ),
      ]);

      await pumpScreen(tester);

      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.textContaining('Tuần này'), findsOneWidget);
    });

    testWidgets('switching tabs shows the budgets of that period only', (
      tester,
    ) async {
      serveBudgets([
        _budget(id: 7),
        _budget(
          id: 8,
          categoryId: 11,
          categoryName: 'Di chuyển',
          periodType: BudgetPeriodType.week,
        ),
      ]);

      await pumpScreen(tester);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('Di chuyển'), findsNothing);

      await tap(tester, find.text('Tuần'));
      expect(find.text('Ăn uống'), findsNothing);
      expect(find.text('Di chuyển'), findsOneWidget);
    });

    testWidgets('a tab without a running budget invites to set one', (
      tester,
    ) async {
      serveBudgets([_budget(id: 7)]);

      await pumpScreen(tester);
      await tap(tester, find.text('Năm'));

      expect(find.text('Chưa có ngân sách cho kỳ này'), findsOneWidget);
      expect(find.byType(BudgetBandSummary), findsNothing);
      await tap(tester, find.text('Thiết lập ngân sách').last);
      expect(find.byType(BudgetFormSheet), findsOneWidget);
      expect(
        find.textContaining('Năm nay:'),
        findsOneWidget,
        reason: 'the new budget starts on the tab it came from',
      );
    });
  });

  group('load failures', () {
    testWidgets('a server error shows the error view and Retry reloads', (
      tester,
    ) async {
      backend.on('GET', '/api/budgets', (_) => jsonResponse(500, {}));

      await pumpScreen(tester);
      expect(find.text('Không tải được ngân sách'), findsOneWidget);
      expect(find.byType(AppStateView), findsOneWidget);

      serveBudgets([_budget()]);
      await tap(tester, find.text('Thử lại'));
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(budgetCalls(), 2);
    });

    testWidgets('transactions that fail to load fail the page too', (
      tester,
    ) async {
      serveBudgets([_budget()]);
      backend.on('GET', '/api/transactions/mine', (_) => jsonResponse(500, {}));

      await pumpScreen(tester);

      expect(find.text('Không tải được ngân sách'), findsOneWidget);
      expect(find.text('Ăn uống'), findsNothing);
    });

    testWidgets('an expired login (403) is reported as such', (tester) async {
      backend.on('GET', '/api/budgets', (_) => jsonResponse(403, {}));

      await pumpScreen(tester);

      expect(
        find.text(
          lookupAppLocalizations(const Locale('vi')).errorSessionExpired,
        ),
        findsOneWidget,
      );
    });

    testWidgets('without a session nothing is asked and the user is told', (
      tester,
    ) async {
      await SessionService.clearSession();
      SharedPreferences.setMockInitialValues({});

      await pumpScreen(tester);

      expect(backend.calls, isEmpty);
      expect(find.text('Phiên đăng nhập hết hạn'), findsOneWidget);
    });
  });

  group('editing', () {
    testWidgets('tapping a budget opens it in the sheet', (tester) async {
      serveBudgets([_budget(amount: 2000000)]);

      await pumpScreen(tester);
      await tap(tester, find.text('Ăn uống'));

      expect(find.text('Sửa ngân sách'), findsOneWidget);
      expect(find.text('2.000.000'), findsOneWidget);
    });

    testWidgets('a saved budget reloads the list', (tester) async {
      serveBudgets([]);
      backend.on('POST', '/api/budgets', (_) => okResponse(_budget()));

      await pumpScreen(tester);
      await tap(tester, find.byKey(BudgetScreen.addKey));
      await tester.enterText(find.byType(TextField).first, '500000');
      await tester.pump();
      serveBudgets([_budget()]);
      await tap(tester, find.byKey(BudgetFormSheet.saveKey));
      await tap(tester, find.text('Xong'));

      expect(backend.calls, contains('POST /api/budgets'));
      expect(backend.requests.last.data, isNot(contains('userId')));
      expect(budgetCalls(), 2);
      expect(find.text('Ăn uống'), findsOneWidget);
    });
  });

  testWidgets(
    'a server that cannot list the categories is reported in the form instead of passing for an empty list',
    (tester) async {
      serveBudgets([]);
      backend.on(
        'GET',
        '/api/categories',
        (_) => jsonResponse(500, {'code': 500, 'message': 'Lỗi hệ thống'}),
      );

      await pumpScreen(tester);
      await tap(tester, find.byKey(BudgetScreen.addKey));

      expect(find.text('Không tải được danh mục'), findsOneWidget);
    },
  );

  group('deleting', () {
    Future<void> swipe(WidgetTester tester) async {
      await tester.drag(find.text('Ăn uống'), const Offset(-600, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('swiping left and confirming deletes the budget', (
      tester,
    ) async {
      serveBudgets([_budget()]);
      backend.on('DELETE', '/api/budgets/7', (_) => okResponse(null));

      await pumpScreen(tester);
      await swipe(tester);
      expect(find.text('Xóa ngân sách?'), findsOneWidget);
      await tap(tester, find.text('Xóa'));

      expect(backend.calls, contains('DELETE /api/budgets/7'));
      expect(find.text('Đã xóa ngân sách'), findsOneWidget);
      await tap(tester, find.text('Xong'));
      expect(find.text('Ăn uống'), findsNothing);
    });

    testWidgets('cancelling the question deletes nothing', (tester) async {
      serveBudgets([_budget()]);

      await pumpScreen(tester);
      await swipe(tester);
      await tap(tester, find.text('Hủy'));

      expect(backend.calls, isNot(contains('DELETE /api/budgets/7')));
      expect(find.text('Ăn uống'), findsOneWidget);
    });

    testWidgets('a failed delete is reported and the budget stays', (
      tester,
    ) async {
      serveBudgets([_budget()]);
      backend.on('DELETE', '/api/budgets/7', (_) => jsonResponse(500, {}));

      await pumpScreen(tester);
      await swipe(tester);
      await tap(tester, find.text('Xóa'));

      expect(find.text('Không xóa được ngân sách'), findsOneWidget);
      await tap(tester, find.text('Đã hiểu'));
      expect(find.text('Ăn uống'), findsOneWidget);
    });
  });
}
