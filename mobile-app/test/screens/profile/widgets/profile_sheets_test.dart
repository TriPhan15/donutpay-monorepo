import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/notification_preferences.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/wallet_model.dart';
import 'package:finance_ai_app/screens/profile/widgets/about_app_sheet.dart';
import 'package:finance_ai_app/screens/profile/widgets/feedback_sheet.dart';
import 'package:finance_ai_app/screens/profile/widgets/money_sources_sheet.dart';
import 'package:finance_ai_app/screens/profile/widgets/notification_settings_sheet.dart';
import 'package:finance_ai_app/screens/profile/widgets/security_sheet.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

import '../../../helpers/fake_backend.dart';
import '../../../helpers/theme_colors.dart';

/// Pumps an empty page under the app themes in [mode] and returns a context the sheets can be opened from.
Future<BuildContext> _host(WidgetTester tester, ThemeMode mode) async {
  // Tall, so that a scrollable sheet builds every row.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late BuildContext host;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            host = context;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return host;
}

final RegExp _emoji = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
  unicode: true,
);

void _expectNoEmoji(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data ?? text.textSpan?.toPlainText() ?? '';
    expect(_emoji.hasMatch(data), isFalse, reason: data);
  }
}

final List<TransactionModel> _transactions = [
  TransactionModel(
    id: '1',
    title: 'Cà phê',
    amount: 45000,
    date: DateTime(2026, 9, 20, 8, 30),
    category: 'Ăn uống',
    isExpense: true,
  ),
  TransactionModel(
    id: '2',
    title: 'Lương',
    amount: 10000000,
    date: DateTime(2026, 9, 1, 9, 0),
    category: 'Lương',
    isExpense: false,
  ),
];

const _wallets = [
  WalletModel(id: 1, name: 'Ví chính', balance: 1500000),
  WalletModel(id: 2, name: 'Ví phụ', balance: -500000),
];

void main() {
  final backend = FakeBackend();

  setUpAll(() => RemoteApiHelper.instance.init(httpClientAdapter: backend));
  setUp(() {
    backend.reset();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(AppToast.resetForTest);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme', () {
      testWidgets(
        'notification settings: two described switches, Save closes with a toast',
        (tester) async {
          final host = await _host(tester, mode);
          showNotificationSettingsSheet(host);
          await tester.pumpAndSettle();
          final colors = Theme.of(host).colorScheme;

          expect(
            materialColor(tester, find.byType(BottomSheet)),
            colors.surface,
          );
          expect(find.text('Cài đặt thông báo'), findsOneWidget);
          expect(find.byType(Switch), findsNWidgets(2));
          expect(find.text('Nhận thông báo trên điện thoại'), findsOneWidget);
          expect(
            find.text('Báo khi chi tới 80% và khi vượt hạn mức'),
            findsOneWidget,
          );
          expect(
            paintedColor(tester, find.text('Nhận thông báo trên điện thoại')),
            colors.onSurfaceVariant,
          );
          _expectNoEmoji(tester);

          await tester.tap(find.byType(Switch).first);
          await tester.pump();
          expect(
            tester.widget<Switch>(find.byType(Switch).first).value,
            isFalse,
          );

          await tester.tap(find.text('Lưu'));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.text('Đã lưu cài đặt thông báo.'), findsOneWidget);

          // The choice is kept on the device and shown the next time the sheet opens.
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getBool(NotificationPreferences.pushKey), isFalse);
          expect(prefs.getBool(NotificationPreferences.budgetAlertKey), isTrue);
          showNotificationSettingsSheet(host);
          await tester.pumpAndSettle();
          expect(
            tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value),
            [false, true],
          );
        },
      );

      testWidgets(
        'money sources: grey balances, the signed total, Done closes',
        (tester) async {
          final host = await _host(tester, mode);
          showMoneySourcesSheet(host, _wallets);
          await tester.pumpAndSettle();
          final colors = Theme.of(host).colorScheme;
          final loc = host.loc;
          String vnd(String digits) => loc.currencyVnd(digits);

          expect(find.text('Ví chính'), findsOneWidget);
          expect(find.text(vnd('1.500.000')), findsOneWidget);
          expect(find.text(vnd('-500.000')), findsOneWidget);
          expect(
            paintedColor(tester, find.text(vnd('1.500.000'))),
            colors.onSurfaceVariant,
          );
          expect(find.text('Tổng'), findsOneWidget);
          expect(find.text(vnd('1.000.000')), findsOneWidget);
          expect(
            paintedColor(tester, find.text(vnd('1.000.000'))),
            colors.onSurface,
          );

          await tester.tap(find.text('Xong'));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
        },
      );

      testWidgets(
        'money sources without wallets: the empty state and no total',
        (tester) async {
          final host = await _host(tester, mode);
          showMoneySourcesSheet(host, const []);
          await tester.pumpAndSettle();

          expect(find.text('Chưa có ví nào.'), findsOneWidget);
          expect(find.text('Tổng'), findsNothing);
        },
      );

      testWidgets(
        'security: change password runs the callback, the log lists the transactions',
        (tester) async {
          final host = await _host(tester, mode);
          var changePassword = 0;
          showSecuritySheet(
            host,
            recentTransactions: _transactions,
            onChangePassword: () => changePassword++,
          );
          await tester.pumpAndSettle();

          expect(find.text('Bảo mật & Quyền riêng tư'), findsOneWidget);
          expect(
            find.text('Đổi xong, thiết bị khác phải đăng nhập lại'),
            findsOneWidget,
          );
          expect(find.text('Xem các giao dịch gần đây'), findsOneWidget);

          await tester.tap(find.text('Đổi mật khẩu'));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(changePassword, 1);

          showSecuritySheet(
            host,
            recentTransactions: _transactions,
            onChangePassword: () => changePassword++,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Lịch sử hoạt động'));
          await tester.pumpAndSettle();

          expect(find.text('Lịch sử hoạt động (2)'), findsOneWidget);
          expect(find.text('Cà phê'), findsOneWidget);
          expect(find.text('Lương'), findsWidgets);
          expect(changePassword, 1);
        },
      );

      testWidgets('activity log without transactions: the empty state', (
        tester,
      ) async {
        final host = await _host(tester, mode);
        showActivityLogSheet(host, const []);
        await tester.pumpAndSettle();

        expect(find.text('Lịch sử hoạt động (0)'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      });

      testWidgets(
        'feedback: chips join the comment once, the stars and text are sent',
        (tester) async {
          backend.on('POST', '/api/reviews', (_) => okResponse(null));
          final host = await _host(tester, mode);
          showFeedbackSheet(host);
          await tester.pumpAndSettle();

          expect(find.text('Đánh giá ứng dụng'), findsOneWidget);
          expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
          _expectNoEmoji(tester);

          await tester.enterText(find.byType(TextField), 'Hay');
          await tester.tap(find.text('Dễ dùng'));
          await tester.pump();
          await tester.tap(find.text('Dễ dùng').first);
          await tester.pump();
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Hay, Dễ dùng',
          );

          await tester.tap(find.byTooltip('3 trên 5 sao'));
          await tester.pump();
          expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));

          await tester.tap(find.text('Gửi ngay'));
          await tester.pumpAndSettle();

          final request = backend.requests.single;
          expect('${request.method} ${request.path}', 'POST /api/reviews');
          final body = request.data is String
              ? jsonDecode(request.data as String)
              : request.data;
          expect(body, {'rating': 3, 'comment': 'Hay, Dễ dùng'});
          expect(find.byType(BottomSheet), findsNothing);
          expect(
            find.text('Cảm ơn bạn đã gửi đánh giá góp ý!'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'feedback: closing the sheet while sending still shows the result',
        (tester) async {
          final answer = Completer<ResponseBody>();
          backend.on('POST', '/api/reviews', (_) => answer.future);
          final host = await _host(tester, mode);
          showFeedbackSheet(host);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Gửi ngay'));
          await tester.pump();
          // A tap above the sheet closes it before the server answers.
          await tester.tapAt(const Offset(400, 20));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);

          answer.complete(okResponse(null));
          await tester.pumpAndSettle();
          expect(
            find.text('Cảm ơn bạn đã gửi đánh giá góp ý!'),
            findsOneWidget,
          );
        },
      );

      testWidgets('feedback: a comment is cut at 1000 characters', (
        tester,
      ) async {
        final host = await _host(tester, mode);
        showFeedbackSheet(host);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'x' * 1100);
        await tester.pump();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'x' * 1000,
        );
      });

      testWidgets('feedback: a failed send says so', (tester) async {
        backend.on(
          'POST',
          '/api/reviews',
          (_) => jsonResponse(500, {'code': 500, 'message': 'boom'}),
        );
        final host = await _host(tester, mode);
        showFeedbackSheet(host);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Gửi ngay'));
        await tester.pumpAndSettle();

        expect(
          find.text('Gửi đánh giá thất bại, vui lòng thử lại sau.'),
          findsOneWidget,
        );
      });

      testWidgets('about: logo, rows and the licence page', (tester) async {
        final host = await _host(tester, mode);
        showAboutAppSheet(host);
        await tester.pumpAndSettle();

        expect(find.text('Về ứng dụng'), findsOneWidget);
        expect(find.text('LedgerMind'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        for (final label in [
          'Phiên bản',
          '1.0.0',
          'Phát triển',
          'Nhóm 7',
          'Trường',
          'HUIT',
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        _expectNoEmoji(tester);

        await tester.tap(find.text('Giấy phép mã nguồn mở'));
        await tester.pumpAndSettle();
        expect(find.byType(LicensePage), findsOneWidget);
      });
    });
  }
}
