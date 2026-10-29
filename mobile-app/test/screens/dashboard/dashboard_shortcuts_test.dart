import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/budget/budget_screen.dart';
import 'package:finance_ai_app/screens/dashboard/dashboard_page.dart';
import 'package:finance_ai_app/screens/ledger/add_transaction_page.dart';
import 'package:finance_ai_app/screens/main_tabs.dart';
import 'package:finance_ai_app/screens/profile/savings_page.dart';
import 'package:finance_ai_app/services/budget_alert_tracker.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';
import 'package:finance_ai_app/widgets/budget/home_budget_band.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/vnd.dart';

/// What every hidden amount of the band shows: the balance and the two month totals.
const String _hidden = '••••••';

/// The shortcuts of the home screen, in the order they are shown.
const List<(IconData, String)> _shortcuts = [
  (Icons.add_circle_outline_rounded, 'Thêm giao dịch'),
  (Icons.receipt_long_rounded, 'Quét hóa đơn'),
  (Icons.account_balance_wallet_rounded, 'Ngân sách'),
  (Icons.savings_rounded, 'Tiết kiệm'),
];

Map<String, Object?> _tx(
  int id,
  String title,
  num amount, {
  required bool isExpense,
}) => {
  'id': id,
  'title': title,
  'amount': amount,
  'date': DateTime.now().toIso8601String(),
  'category': 'Ăn uống',
  'isExpense': isExpense,
};

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// A monthly budget on "Ăn uống" for this month: 45 000 of 1 000 000 is spent, far from any alert.
Map<String, Object?> _monthBudget() {
  final now = DateTime.now();
  return {
    'id': 1,
    'categoryId': 10,
    'categoryName': 'Ăn uống',
    'amount': 1000000,
    'periodType': 'MONTH',
    'startDate': _ymd(DateTime(now.year, now.month, 1)),
    'endDate': _ymd(DateTime(now.year, now.month + 1, 0)),
  };
}

Finder _shortcut(IconData icon) => find.byIcon(icon);

void main() {
  final backend = FakeBackend();
  var budgets = <Map<String, Object?>>[];

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    // The home screen also reads the transactions waiting to be sent; the fake keeps it away from a real database.
    AppRepository.instance.localStore = FakeLocalStore();
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

    backend.reset();
    budgets = [];
    backend.on(
      'GET',
      '/api/users/me',
      (_) => okResponse({
        'id': 1,
        'email': 'an@example.com',
        'walletBalance': 4955000,
      }),
    );
    backend.on(
      'GET',
      '/api/transactions/mine',
      (_) => okResponse([
        _tx(7, 'Cà phê', 45000, isExpense: true),
        _tx(8, 'Lương tháng', 5000000, isExpense: false),
      ]),
    );
    backend.on('GET', '/api/budgets', (_) => okResponse(budgets));
    backend.on('GET', '/api/categories', (_) => okResponse([]));
    backend.on('GET', '/api/savings', (_) => okResponse([]));
    backend.on('GET', '/api/notifications/unread-count', (_) => okResponse(0));
  });

  // The language cubit of withAppSettings sets the default locale of intl.
  tearDown(() => Intl.defaultLocale = null);

  Future<void> showDashboard(
    WidgetTester tester, {
    ValueChanged<int>? onOpenTransaction,
    VoidCallback? onScanReceipt,
    FakeSettingsRepository? settings,
    Size size = const Size(600, 3000),
  }) async {
    // Tall and wide, because the test font is much wider than a real one and the rows would overflow at phone width.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        settings: settings,
        Scaffold(
          body: DashboardPage(
            onOpenTransaction: onOpenTransaction,
            onScanReceipt: onScanReceipt,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('balance', () {
    testWidgets(
      'is hidden when the home screen opens; the eye shows it and hides it again',
      (tester) async {
        await showDashboard(tester);

        // The balance and the two month totals.
        expect(find.text(_hidden), findsNWidgets(3));
        expect(find.text(vnd(5000000 - 45000)), findsNothing);
        expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.visibility_off_rounded));
        await tester.pumpAndSettle();
        expect(find.text(vnd(5000000 - 45000)), findsOneWidget);
        expect(find.text('Thu 5 tr'), findsOneWidget);
        expect(find.text('Chi 45k'), findsOneWidget);
        expect(find.text(_hidden), findsNothing);

        await tester.tap(find.byIcon(Icons.visibility_rounded));
        await tester.pumpAndSettle();
        expect(find.text(_hidden), findsNWidgets(3));
      },
    );

    testWidgets('the choice is kept on a new home screen', (tester) async {
      final settings = FakeSettingsRepository();
      await showDashboard(tester, settings: settings);
      await tester.tap(find.byIcon(Icons.visibility_off_rounded));
      await tester.pumpAndSettle();
      expect(settings.amountsHidden, isFalse);

      await tester.pumpWidget(const SizedBox());
      await showDashboard(tester, settings: settings);

      expect(find.text(_hidden), findsNothing);
      expect(find.text(vnd(5000000 - 45000)), findsOneWidget);
    });

    testWidgets('the eye sits right of the balance, on its line', (
      tester,
    ) async {
      await showDashboard(
        tester,
        settings: FakeSettingsRepository()..amountsHidden = false,
      );

      final balance = tester.getRect(find.text(vnd(5000000 - 45000)));
      final eye = tester.getCenter(find.byIcon(Icons.visibility_rounded));
      expect(eye.dx, greaterThan(balance.right));
      expect(eye.dy, inInclusiveRange(balance.top, balance.bottom));
    });

    testWidgets('the eye is 30 to see but 48 to tap', (tester) async {
      await showDashboard(tester);
      final icon = find.byIcon(Icons.visibility_off_rounded);

      expect(
        tester.getSize(
          find.ancestor(of: icon, matching: find.byType(Material)).first,
        ),
        const Size(30, 30),
      );
      expect(
        tester.getSize(
          find.ancestor(of: icon, matching: find.byType(InkWell)).first,
        ),
        const Size(48, 48),
      );

      // A tap just outside the visible square still toggles.
      await tester.tapAt(tester.getCenter(icon) + const Offset(0, 21));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    });
  });

  group('shortcuts', () {
    testWidgets(
      'four shortcuts of the same width in one row, each a round icon over its label; no Reports or All',
      (tester) async {
        await showDashboard(tester);

        final widths = <double>{};
        final tops = <double>{};
        double? previousLeft;
        for (final (icon, label) in _shortcuts) {
          expect(_shortcut(icon), findsOneWidget, reason: label);
          expect(find.text(label), findsOneWidget, reason: label);
          final circle = tester.widget<Container>(
            find
                .ancestor(of: _shortcut(icon), matching: find.byType(Container))
                .first,
          );
          expect(
            (circle.decoration! as BoxDecoration).shape,
            BoxShape.circle,
            reason: label,
          );
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, 2, reason: label);

          final tile = find
              .ancestor(of: _shortcut(icon), matching: find.byType(Expanded))
              .first;
          widths.add(tester.getSize(tile).width);
          final left = tester.getTopLeft(_shortcut(icon)).dx;
          tops.add(tester.getTopLeft(_shortcut(icon)).dy);
          if (previousLeft != null) {
            expect(left, greaterThan(previousLeft), reason: label);
          }
          previousLeft = left;
        }
        expect(widths, hasLength(1), reason: 'evenly sized');
        expect(tops, hasLength(1), reason: 'one row');
        expect(find.text('Báo cáo'), findsNothing);
        expect(find.text('Tất cả'), findsNothing);
        expect(find.byIcon(Icons.pie_chart_rounded), findsNothing);
        expect(find.byIcon(Icons.grid_view_rounded), findsNothing);
      },
    );

    testWidgets('"Thêm giao dịch" opens the add transaction form', (
      tester,
    ) async {
      await showDashboard(tester);

      await tester.tap(_shortcut(Icons.add_circle_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AddTransactionPage), findsOneWidget);
    });

    testWidgets('"Quét hóa đơn" asks for the scan options of the app', (
      tester,
    ) async {
      var scans = 0;
      await showDashboard(tester, onScanReceipt: () => scans++);

      await tester.tap(_shortcut(Icons.receipt_long_rounded));
      await tester.pumpAndSettle();

      expect(scans, 1);
    });

    testWidgets('"Ngân sách" opens the budget screen', (tester) async {
      await showDashboard(tester);

      await tester.tap(_shortcut(Icons.account_balance_wallet_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(BudgetScreen), findsOneWidget);
    });

    testWidgets('"Tiết kiệm" opens the savings page', (tester) async {
      await showDashboard(tester);

      await tester.tap(_shortcut(Icons.savings_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SavingsPage), findsOneWidget);
    });
  });

  group('budget band', () {
    testWidgets('tapping the band opens the budget screen', (tester) async {
      budgets = [_monthBudget()];
      await showDashboard(tester);
      expect(find.byType(HomeBudgetBand), findsOneWidget);

      await tester.tap(find.text('4%'));
      await tester.pumpAndSettle();

      expect(find.byType(BudgetScreen), findsOneWidget);
    });

    testWidgets('with no budget the band invites and opens the budget screen', (
      tester,
    ) async {
      await showDashboard(tester);

      await tester.tap(find.text('Đặt ngân sách tháng này'));
      await tester.pumpAndSettle();

      expect(find.byType(BudgetScreen), findsOneWidget);
    });
  });

  group('recent transactions', () {
    testWidgets('tapping one asks to show it by its server id', (tester) async {
      final opened = <int>[];
      await showDashboard(tester, onOpenTransaction: opened.add);

      await tester.tap(find.text('Cà phê'));
      await tester.pumpAndSettle();
      expect(opened, [7]);

      await tester.tap(find.text('Lương tháng'));
      await tester.pumpAndSettle();
      expect(opened, [7, 8]);
    });

    testWidgets('"Xem tất cả" shows the ledger tab', (tester) async {
      final shown = <MainTab>[];
      void show(MainTab tab) => shown.add(tab);
      MainTabs.attach(show);
      addTearDown(() => MainTabs.detach(show));
      await showDashboard(tester);

      await tester.tap(find.text('Xem tất cả'));
      await tester.pumpAndSettle();

      expect(shown, [MainTab.ledger]);
    });

    testWidgets('without a MainScaffold "Xem tất cả" is not shown', (
      tester,
    ) async {
      await showDashboard(tester);

      expect(find.text('Xem tất cả'), findsNothing);
    });
  });
}
