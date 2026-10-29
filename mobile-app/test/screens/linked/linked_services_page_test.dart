import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/screens/linked/linked_services_page.dart';
import 'package:finance_ai_app/screens/linked/top_up_sheet.dart';
import 'package:finance_ai_app/screens/linked/widgets/syncing_banner.dart';
import 'package:finance_ai_app/screens/linked/widgets/top_up_quick_amounts.dart';
import 'package:finance_ai_app/screens/linked/widgets/wallet_list_card.dart';
import 'package:finance_ai_app/screens/payment/payment_history_screen.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';

const MethodChannel _urlLauncher = MethodChannel(
  'plugins.flutter.io/url_launcher',
);

void main() {
  final backend = FakeBackend();
  final launched = <String>[];

  setUpAll(() => RemoteApiHelper.instance.init(httpClientAdapter: backend));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend.reset();
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
    backend.on('GET', '/api/payment/mine', (_) => okResponse([]));
    launched.clear();
    // The payment gateway opens in another app: here it is only recorded.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncher, (call) async {
          if (call.method == 'launch') {
            launched.add('${(call.arguments as Map)['url']}');
          }
          return true;
        });
  });

  tearDown(() => Intl.defaultLocale = null);

  Future<ThemeData> show(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
    AppLanguage language = AppLanguage.vietnamese,
  }) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        const LinkedServicesPage(),
        settings: FakeSettingsRepository(themeMode: mode, language: language),
      ),
    );
    await tester.pumpAndSettle();
    return Theme.of(tester.element(find.byType(LinkedServicesPage)));
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mode.name}: band, wallets and demo note follow the theme', (
      tester,
    ) async {
      final theme = await show(tester, mode: mode);
      final colors = theme.colorScheme;
      final semantic = theme.semanticColors;

      expect(
        paintedColor(
          tester,
          find.descendant(
            of: find.byType(PageBand),
            matching: find.text('Dịch vụ liên kết'),
          ),
        ),
        BandColors.primary,
      );
      expect(
        paintedColor(
          tester,
          find.text('Đồng bộ tiền từ ví vào ngân sách để quản lý chi tiêu.'),
        ),
        colors.onSurfaceVariant,
      );
      for (final name in ['VNPAY', 'ZaloPay', 'Ví Demo']) {
        expect(paintedColor(tester, find.text(name)), colors.onSurface);
      }
      expect(find.text('Đã liên kết'), findsNWidgets(3));
      expect(
        paintedColor(tester, find.text('Đã liên kết').first),
        semantic.successColor,
      );
      expect(boxColor(tester, find.text('VNPAY')), colors.surface);
      expect(
        tester
            .widget<Material>(find.byKey(WalletListCard.syncKey('VNPAY')))
            .color,
        colors.primaryContainer,
      );
      expect(
        paintedColor(
          tester,
          find.descendant(
            of: find.byKey(WalletListCard.syncKey('VNPAY')),
            matching: find.text('Đồng bộ'),
          ),
        ),
        colors.primary,
      );
      expect(
        find.textContaining('dữ liệu giả lập, không kết nối ngân hàng'),
        findsOneWidget,
      );
      expect(find.byType(SyncingBanner), findsNothing);
    });
  }

  testWidgets('Đồng bộ opens the amount sheet; closing it sends nothing', (
    tester,
  ) async {
    await show(tester);

    await tester.tap(find.byKey(WalletListCard.syncKey('ZALOPAY')));
    await tester.pumpAndSettle();

    expect(find.byType(TopUpSheet), findsOneWidget);
    expect(find.text('Từ ZaloPay'), findsOneWidget);

    await tester.tap(find.byKey(TopUpSheet.closeKey));
    await tester.pumpAndSettle();

    expect(find.byType(TopUpSheet), findsNothing);
    expect(backend.calls, isEmpty);
    expect(find.byType(SyncingBanner), findsNothing);
  });

  /// Opens the page from a host route; the list receives what it pops.
  Future<List<Object?>> openFromHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final popped = <Object?>[];
    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => popped.add(
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LinkedServicesPage()),
              ),
            ),
            child: const Text('host'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('host'));
    await tester.pumpAndSettle();
    return popped;
  }

  /// Syncs 200.000 ₫ from VNPAY through the sheet.
  Future<void> syncFromVnpay(WidgetTester tester) async {
    await tester.tap(find.byKey(WalletListCard.syncKey('VNPAY')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TopUpQuickAmounts.chipKey(200000)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TopUpSheet.submitKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  int statusCalls() =>
      backend.calls.where((c) => c == 'GET /api/payment/status/O1').length;

  testWidgets('a paid sync waits under the banner, then refreshes and pops', (
    tester,
  ) async {
    var checks = 0;
    backend.on(
      'POST',
      '/api/payment/create',
      (_) => okResponse({'orderCode': 'O1', 'payUrl': 'https://pay.test/O1'}),
    );
    backend.on(
      'GET',
      '/api/payment/status/O1',
      (_) => okResponse({'status': ++checks < 2 ? 'PENDING' : 'SUCCESS'}),
    );
    final changes = RemoteApiHelper.instance.dataChangedNotifier.value;
    final popped = await openFromHost(tester);

    await syncFromVnpay(tester);

    final create = backend.requests.singleWhere(
      (r) => r.path == '/api/payment/create',
    );
    expect(create.data, {
      'type': 'DEPOSIT',
      'amount': 200000.0,
      'provider': 'VNPAY',
    });
    expect(launched, ['https://pay.test/O1']);
    expect(find.byType(SyncingBanner), findsOneWidget);
    expect(find.textContaining('200.000'), findsWidgets);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SyncingBanner), findsOneWidget, reason: 'still pending');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(popped, [true]);
    expect(
      RemoteApiHelper.instance.dataChangedNotifier.value,
      greaterThan(changes),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(statusCalls(), 2);
  });

  testWidgets('without an answer in 60 checks the wait ends with a toast', (
    tester,
  ) async {
    backend.on(
      'POST',
      '/api/payment/create',
      (_) => okResponse({'orderCode': 'O1', 'payUrl': 'https://pay.test/O1'}),
    );
    backend.on(
      'GET',
      '/api/payment/status/O1',
      (_) => okResponse({'status': 'PENDING'}),
    );
    await show(tester);

    await syncFromVnpay(tester);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(statusCalls(), 60);
    expect(find.byType(SyncingBanner), findsNothing);
    expect(
      find.textContaining('Chưa nhận được kết quả thanh toán'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(statusCalls(), 60, reason: 'the checks stop');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('leaving while the order is created starts no status checks', (
    tester,
  ) async {
    final created = Completer<void>();
    backend.on('POST', '/api/payment/create', (_) async {
      await created.future;
      return okResponse({'orderCode': 'O1', 'payUrl': 'https://pay.test/O1'});
    });
    backend.on(
      'GET',
      '/api/payment/status/O1',
      (_) => okResponse({'status': 'PENDING'}),
    );
    await openFromHost(tester);

    await syncFromVnpay(tester);
    // The band stays tappable while the order is created.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LinkedServicesPage), findsNothing);
    created.complete();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(find.byType(LinkedServicesPage), findsNothing);
    expect(statusCalls(), 0);
  });

  testWidgets('the clock in the band opens the history', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(LinkedServicesPage.historyKey));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentHistoryScreen), findsOneWidget);
  });

  testWidgets('the syncing banner shows its message with a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      withAppSettings(
        const Scaffold(body: SyncingBanner(message: 'Đang đồng bộ…')),
      ),
    );
    await tester.pump();

    expect(find.text('Đang đồng bộ…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('in English the wallets and the page speak English', (
    tester,
  ) async {
    await show(tester, language: AppLanguage.english);

    expect(find.text('Linked services'), findsOneWidget);
    expect(find.text('Demo wallet'), findsOneWidget);
    expect(find.text('Linked'), findsNWidgets(3));
    expect(find.text('Sync'), findsNWidgets(3));
  });
}
