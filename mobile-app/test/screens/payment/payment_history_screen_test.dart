import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/screens/payment/payment_history_screen.dart';
import 'package:finance_ai_app/screens/payment/widgets/payment_order_row.dart';
import 'package:finance_ai_app/screens/payment/widgets/payment_order_sheet.dart';
import 'package:finance_ai_app/screens/payment/widgets/payment_status_pill.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';

/// Amounts as the Vietnamese screens write them.
String _money(num amount) => CurrencyHelper.formatVND(
  amount.toDouble(),
  AppLanguage.vietnamese.localizations,
  showSign: false,
);

Map<String, Object?> _order(
  String code,
  String type,
  String status,
  num amount,
  String provider,
) => {
  'orderCode': code,
  'type': type,
  'status': status,
  'amount': amount,
  'provider': provider,
  'createdAt': '2026-09-20T08:30:00',
};

final List<Map<String, Object?>> _orders = [
  _order('A1', 'DEPOSIT', 'SUCCESS', 100000, 'VNPAY'),
  _order('A2', 'WITHDRAW', 'FAILED', 50000, 'ZALOPAY'),
  _order('A3', 'DEPOSIT', 'CANCELLED', 20000, 'MOCK'),
  _order('A4', 'DEPOSIT', 'PENDING', 30000, 'VNPAY'),
];

void main() {
  final backend = FakeBackend();

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

    backend.reset();
    backend.on('GET', '/api/payment/mine', (_) => okResponse(_orders));
  });

  tearDown(() => Intl.defaultLocale = null);

  Future<ThemeData> show(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
    AppLanguage language = AppLanguage.vietnamese,
  }) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        const PaymentHistoryScreen(),
        settings: FakeSettingsRepository(themeMode: mode, language: language),
      ),
    );
    await tester.pumpAndSettle();
    return Theme.of(tester.element(find.byType(PaymentHistoryScreen)));
  }

  Finder row(String code) => find.byKey(PaymentOrderRow.keyOf(code));

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mode.name}: rows, amounts and pills follow the theme', (
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
            matching: find.text('Lịch sử nạp/rút'),
          ),
        ),
        BandColors.primary,
      );
      expect(find.byType(PaymentOrderRow), findsNWidgets(4));
      expect(boxColor(tester, row('A1')), colors.surface);
      expect(
        find.descendant(of: row('A1'), matching: find.text('VNPAY')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('A2'), matching: find.text('ZaloPay')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('A3'), matching: find.text('Ví Demo')),
        findsOneWidget,
      );

      // A successful deposit is green; a cancelled one is struck through.
      expect(
        paintedColor(tester, find.text('+${_money(100000)}')),
        semantic.incomeColor,
      );
      final cancelled = tester
          .widget<Text>(find.text('+${_money(20000)}'))
          .style!;
      expect(cancelled.decoration, TextDecoration.lineThrough);
      expect(cancelled.color, colors.onSurfaceVariant);
      expect(
        paintedColor(tester, find.text('-${_money(50000)}')),
        colors.onSurfaceVariant,
      );
      expect(
        paintedColor(tester, find.text('+${_money(30000)}')),
        colors.onSurface,
      );
      expect(
        find.descendant(
          of: row('A1'),
          matching: find.text('Nạp tiền · 20/09 08:30'),
        ),
        findsOneWidget,
      );

      for (final (status, color) in [
        ('Thành công', semantic.successColor),
        ('Thất bại', colors.error),
        ('Đã hủy', colors.onSurfaceVariant),
        ('Đang chờ', semantic.warningColor),
      ]) {
        expect(paintedColor(tester, find.text(status)), color, reason: status);
        final tint = color.withValues(alpha: PaymentStatusPill.tintAlpha);
        expect(boxColor(tester, find.text(status)), tint, reason: status);
        if (mode == ThemeMode.dark) {
          expect(
            contrastRatio(color, over(tint, colors.surface)),
            greaterThanOrEqualTo(4.5),
            reason: status,
          );
        }
      }
      expect(find.text('Hủy đơn'), findsNothing, reason: 'only in the sheet');
    });

    testWidgets('${mode.name}: the pending order sheet offers Hủy đơn', (
      tester,
    ) async {
      final colors = (await show(tester, mode: mode)).colorScheme;

      await tester.tap(row('A4'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết đơn'), findsOneWidget);
      for (final label in ['Ví', 'Mã đơn', 'Thời gian']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('A4'), findsOneWidget);
      expect(find.text('20/09/2026 08:30'), findsOneWidget);
      final cancel = find.byKey(PaymentOrderSheet.cancelKey);
      final fill = materialColor(tester, cancel)!;
      expect(
        fill,
        colors.error.withValues(alpha: PaymentOrderSheet.cancelTint),
      );
      expect(paintedColor(tester, find.text('Hủy đơn')), colors.error);
      expect(
        contrastRatio(colors.error, over(fill, colors.surface)),
        greaterThanOrEqualTo(mode == ThemeMode.dark ? 4.5 : 3),
      );
    });
  }

  testWidgets('cancelling a pending order cancels it and reloads', (
    tester,
  ) async {
    backend.on(
      'PUT',
      '/api/payment/cancel/A4',
      (_) => okResponse({'orderCode': 'A4', 'status': 'CANCELLED'}),
    );
    await show(tester);

    await tester.tap(row('A4'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PaymentOrderSheet.cancelKey));
    await tester.pumpAndSettle();
    // The success toast goes away on its own.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(backend.calls, [
      'GET /api/payment/mine',
      'PUT /api/payment/cancel/A4',
      'GET /api/payment/mine',
    ]);
    expect(find.byType(PaymentOrderSheet), findsNothing);
  });

  testWidgets('a finished order has no Hủy đơn and closes without a call', (
    tester,
  ) async {
    await show(tester);

    await tester.tap(row('A1'));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết đơn'), findsOneWidget);
    expect(find.byKey(PaymentOrderSheet.cancelKey), findsNothing);

    await tester.tap(find.byKey(PaymentOrderSheet.closeKey));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentOrderSheet), findsNothing);
    expect(backend.calls, ['GET /api/payment/mine']);
  });

  testWidgets(
    'a long code and a large amount fit a narrow screen in large text',
    (tester) async {
      backend.on(
        'GET',
        '/api/payment/mine',
        (_) => okResponse([
          _order(
            'ZP-2026102809120000-ABCDEFGHIJKLMNOP',
            'DEPOSIT',
            'PENDING',
            123456789000,
            'ZALOPAY',
          ),
        ]),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(withAppSettings(const PaymentHistoryScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(PaymentOrderRow));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PaymentOrderSheet), findsOneWidget);
    },
  );

  testWidgets('an empty history shows the empty state', (tester) async {
    backend.on('GET', '/api/payment/mine', (_) => okResponse([]));
    await show(tester);

    expect(find.byType(AppStateView), findsOneWidget);
    expect(find.text('Chưa có giao dịch nạp/rút.'), findsOneWidget);
  });

  testWidgets('a failed load offers to retry', (tester) async {
    backend.on(
      'GET',
      '/api/payment/mine',
      (_) => jsonResponse(500, {'code': 500}),
    );
    await show(tester);

    expect(find.byType(AppStateView), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    backend.on('GET', '/api/payment/mine', (_) => okResponse(_orders));
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentOrderRow), findsNWidgets(4));
  });

  testWidgets('in English the history speaks English', (tester) async {
    await show(tester, language: AppLanguage.english);

    expect(find.text('Deposit/withdrawal history'), findsOneWidget);
    expect(find.text('Demo wallet'), findsOneWidget);
    for (final status in ['Successful', 'Failed', 'Cancelled', 'Pending']) {
      expect(find.text(status), findsOneWidget, reason: status);
    }

    await tester.tap(row('A4'));
    await tester.pumpAndSettle();
    expect(find.text('Order details'), findsOneWidget);
    expect(find.text('Cancel order'), findsOneWidget);
  });
}
