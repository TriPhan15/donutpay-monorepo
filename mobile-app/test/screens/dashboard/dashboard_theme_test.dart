import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/dashboard/dashboard_page.dart';
import 'package:finance_ai_app/screens/dashboard/widgets/home_header_band.dart';
import 'package:finance_ai_app/screens/dashboard/widgets/home_recent_card.dart';
import 'package:finance_ai_app/screens/ledger/add_transaction_page.dart';
import 'package:finance_ai_app/services/budget_alert_tracker.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';
import 'package:finance_ai_app/widgets/budget/home_budget_band.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/fake_scan_queue.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';
import '../../helpers/vnd.dart';

Map<String, Object?> _tx(
  int id,
  String title,
  num amount, {
  required bool isExpense,
  String category = 'Ăn uống',
}) => {
  'id': id,
  'title': title,
  'amount': amount,
  'date': DateTime.now().toIso8601String(),
  'category': category,
  'isExpense': isExpense,
};

/// A budget of this month; [amount] 1 makes any expense exceed it.
Map<String, Object?> _monthBudget({String? category, num amount = 1000000}) {
  final now = DateTime.now();
  String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  return {
    'id': 1,
    'categoryId': category == null ? null : 10,
    'categoryName': category,
    'amount': amount,
    'periodType': 'MONTH',
    'startDate': ymd(DateTime(now.year, now.month, 1)),
    'endDate': ymd(DateTime(now.year, now.month + 1, 0)),
  };
}

void main() {
  final backend = FakeBackend();
  final scanQueue = FakeScanQueue();
  var transactions = <Map<String, Object?>>[];

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    // The home screen also reads the transactions waiting to be sent; the fake keeps it away from a real database.
    AppRepository.instance.localStore = FakeLocalStore();
    // The band listens to the scan queue; the fake keeps the database out and lets a test show the strip.
    ReceiptScanQueue.instanceForTesting = scanQueue;
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
    BudgetAlertTracker.instance.resetMemory();
    BudgetAlertPresenter.resetQueue();

    backend.reset();
    transactions = [
      _tx(1, 'Cà phê', 45000, isExpense: true),
      _tx(2, 'Lương tháng', 5000000, isExpense: false, category: 'Lương'),
    ];
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
      (_) => okResponse(transactions),
    );
    backend.on('GET', '/api/budgets', (_) => okResponse([]));
    // The home screen also asks for the number on its notification bell.
    backend.on('GET', '/api/notifications/unread-count', (_) => okResponse(0));
  });

  // The language cubit of withAppSettings sets the default locale of intl.
  tearDown(() => Intl.defaultLocale = null);

  /// The home tab as MainScaffold shows it: in a Scaffold, whose page colour shows through the tab.
  Future<void> showDashboard(WidgetTester tester, ThemeMode mode) async {
    // Tall and wide, because the test font is much wider than a real one and the rows would overflow at phone width.
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        const Scaffold(body: DashboardPage()),
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
  }

  ThemeData themeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(DashboardPage)));

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme', () {
      testWidgets(
        'the band paints headerGradient, no decoration, white text on the 7-step scale',
        (tester) async {
          await showDashboard(tester, mode);
          await tester.pumpAndSettle();
          final theme = themeOf(tester);
          final white80 = Colors.white.withValues(alpha: 0.8);
          final white18 = Colors.white.withValues(alpha: 0.18);

          expect(
            theme.brightness,
            mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
          );
          final band = boxDecoration(tester, find.text('Số dư'));
          expect(band.gradient, theme.semanticColors.headerGradient);
          expect(
            band.borderRadius,
            const BorderRadius.vertical(bottom: Radius.circular(28)),
          );
          expect(find.byType(ImageFiltered), findsNothing);

          expect(paintedColor(tester, find.text('Xin chào,')), white80);
          expect(paintedColor(tester, find.text('Số dư')), white80);
          expect(paintedColor(tester, find.text('an')), Colors.white);
          expect(
            tester.widget<Text>(find.text('an')).style?.fontSize,
            AppTextSize.pageTitle,
          );
          expect(
            paintedColor(tester, find.byIcon(Icons.notifications_outlined)),
            Colors.white,
          );

          // The eye shows the amounts: the balance, then the two month pills.
          await tester.tap(find.byIcon(Icons.visibility_off_rounded));
          await tester.pumpAndSettle();
          final balance = find.text(vnd(5000000 - 45000));
          expect(paintedColor(tester, balance), Colors.white);
          expect(
            tester.widget<Text>(balance).style?.fontSize,
            AppTextSize.amountLarge,
          );
          for (final pill in ['Thu 5 tr', 'Chi 45k']) {
            expect(paintedColor(tester, find.text(pill)), Colors.white);
            expect(
              tester.widget<Text>(find.text(pill)).style?.fontSize,
              AppTextSize.secondary,
              reason: pill,
            );
            expect(boxColor(tester, find.text(pill)), white18, reason: pill);
          }

          // A shortcut: a round translucent white tile, a white icon and a 12 white label.
          final savings = find.byIcon(Icons.savings_rounded);
          expect(boxColor(tester, savings), white18);
          expect(paintedColor(tester, savings), Colors.white);
          expect(paintedColor(tester, find.text('Tiết kiệm')), Colors.white);
          expect(
            tester.widget<Text>(find.text('Tiết kiệm')).style?.fontSize,
            AppTextSize.caption,
          );
        },
      );

      testWidgets('the band fits 320 px at text scale 1.3', (tester) async {
        // The band with a budget and a scan in progress; the recent rows have their own narrow-screen check.
        transactions = [];
        backend.on(
          'GET',
          '/api/budgets',
          (_) => okResponse([_monthBudget(category: 'Mua sắm', amount: 1)]),
        );
        scanQueue.progressNotifier.value = const ScanQueueProgress(
          done: 8,
          total: 10,
          ready: 8,
        );
        addTearDown(scanQueue.reset);
        tester.view.physicalSize = const Size(320, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          withAppSettings(
            MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.3,
              maxScaleFactor: 1.3,
              child: const Scaffold(body: DashboardPage()),
            ),
            settings: FakeSettingsRepository(themeMode: mode)
              ..amountsHidden = false,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(HomeBudgetBand), findsOneWidget);
        expect(find.text('Đang đọc hóa đơn 9/10'), findsOneWidget);
        for (final label in [
          'Thêm giao dịch',
          'Quét hóa đơn',
          'Ngân sách',
          'Tiết kiệm',
        ]) {
          final inBand = find.descendant(
            of: find.byType(HomeHeaderBand),
            matching: find.text(label),
          );
          expect(tester.widget<Text>(inBand).maxLines, 2);
        }
      });

      testWidgets(
        'recent rows share one surface card, split by outlineVariant dividers',
        (tester) async {
          await showDashboard(tester, mode);
          await tester.pumpAndSettle();
          final theme = themeOf(tester);
          final colors = theme.colorScheme;
          final card = find.byType(HomeRecentCard);

          expect(find.text('Gần đây'), findsOneWidget);
          expect(
            tester.widget<Text>(find.text('Gần đây')).style?.fontSize,
            AppTextSize.title,
          );
          // One surface block around both rows.
          final block = boxDecoration(tester, find.text('Cà phê'));
          expect(block.color, colors.surface);
          expect(block.borderRadius, BorderRadius.circular(20));
          expect(boxDecoration(tester, find.text('Lương tháng')), block);
          final dividers = tester.widgetList<Divider>(
            find.descendant(of: card, matching: find.byType(Divider)),
          );
          expect(dividers, hasLength(1));
          expect(dividers.single.color, colors.outlineVariant);

          // Name 14 in the text colour, category 13 secondary, time 12 secondary.
          final name = tester.widget<Text>(find.text('Cà phê'));
          expect(name.style?.fontSize, AppTextSize.body);
          expect(paintedColor(tester, find.text('Cà phê')), colors.onSurface);
          final category = find.descendant(
            of: card,
            matching: find.text('Ăn uống'),
          );
          expect(
            tester.widget<Text>(category.first).style?.fontSize,
            AppTextSize.secondary,
          );
          expect(paintedColor(tester, category.first), colors.onSurfaceVariant);
          final time = find.textContaining('Hôm nay').first;
          expect(
            tester.widget<Text>(time).style?.fontSize,
            AppTextSize.caption,
          );
          expect(paintedColor(tester, time), colors.onSurfaceVariant);

          // Spending in the text colour with its minus, income in green with its plus.
          expect(
            paintedColor(tester, find.text(vnd(-45000))),
            colors.onSurface,
          );
          expect(
            paintedColor(tester, find.text('+${vnd(5000000)}')),
            theme.semanticColors.successColor,
          );

          // The category tile: a pale tile of the category colour, the icon in the colour itself.
          final food = CategoryColors.accentFor('Ăn uống', colors);
          final icon = find.descendant(
            of: card,
            matching: find.byIcon(TransactionCategories.iconFor('Ăn uống')),
          );
          expect(paintedColor(tester, icon.first), food);
          expect(
            boxColor(tester, icon.first),
            CategoryColors.tileFor(food, theme.brightness),
          );
        },
      );

      testWidgets(
        'first load shows the small grey spinner, an empty list offers to add a transaction',
        (tester) async {
          final answer = Completer<ResponseBody>();
          backend.on('GET', '/api/transactions/mine', (_) => answer.future);

          await showDashboard(tester, mode);
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(AppStateView), findsOneWidget);
          expect(find.byType(HomeHeaderBand), findsNothing);

          answer.complete(okResponse(<Object>[]));
          await tester.pumpAndSettle();
          final empty = find.ancestor(
            of: find.text('Chưa có giao dịch nào.'),
            matching: find.byType(AppStateView),
          );
          expect(empty, findsOneWidget);
          expect(
            boxColor(tester, find.text('Chưa có giao dịch nào.')),
            themeOf(tester).colorScheme.surface,
          );

          await tester.tap(
            find.descendant(of: empty, matching: find.text('Thêm giao dịch')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AddTransactionPage), findsOneWidget);
        },
      );

      testWidgets('a recent row fits 320 px at text scale 1.3', (tester) async {
        transactions = [
          _tx(
            1,
            'Một ghi chú khá dài cho giao dịch',
            1234567890,
            isExpense: true,
          ),
        ];
        tester.view.physicalSize = const Size(320, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          withAppSettings(
            MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.3,
              maxScaleFactor: 1.3,
              child: const Scaffold(body: DashboardPage()),
            ),
            settings: FakeSettingsRepository(themeMode: mode),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('dark mode: the category icons stay readable on their tiles', (
    tester,
  ) async {
    await showDashboard(tester, ThemeMode.dark);
    await tester.pumpAndSettle();
    final theme = themeOf(tester);
    final colors = theme.colorScheme;

    for (final icon in tester.widgetList<Icon>(
      find.descendant(
        of: find.byType(HomeRecentCard),
        matching: find.byIcon(TransactionCategories.iconFor('Ăn uống')),
      ),
    )) {
      final tile = over(
        CategoryColors.tileFor(icon.color!, theme.brightness),
        colors.surface,
      );
      expect(contrastRatio(icon.color!, tile), greaterThanOrEqualTo(3));
    }
  });
}
