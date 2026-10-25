import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/screens/auth/login_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';

const String _loginPath = '/api/auth/login';
const String _failedTitle = 'Đăng nhập thất bại';

void main() {
  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    SharedPreferences.setMockInitialValues({});
    backend.reset();
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  Future<void> signIn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(withAppSettings(const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'an@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'Secret123');
    await tester.tap(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  for (final (failure, answer, expected) in [
    (
      'a 401',
      (RequestOptions _) => jsonResponse(401, {'code': 401}),
      'Sai email hoặc mật khẩu!',
    ),
    (
      'a 401 with the server message',
      (RequestOptions _) =>
          jsonResponse(401, {'code': 401, 'message': 'Tài khoản đã bị khóa'}),
      'Tài khoản đã bị khóa',
    ),
    (
      'a server failure',
      (RequestOptions _) => jsonResponse(500, {
        'code': 500,
        'message': 'Hệ thống sự cố: java.lang.NullPointerException',
      }),
      'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
    ),
    (
      'no connection',
      (RequestOptions _) =>
          throw const SocketException('Failed host lookup: api.ledgermind.dev'),
      'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.',
    ),
  ]) {
    testWidgets(
      '$failure is told apart with a fixed text, never the raw error',
      (tester) async {
        backend.on('POST', _loginPath, answer);

        await withCapturedLogs((logs) async {
          await signIn(tester);
          expect(logs, isNotEmpty, reason: 'the raw error goes to the log');
        });

        expect(find.text(_failedTitle), findsOneWidget);
        expect(find.text(expected), findsOneWidget);
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('http'), findsNothing);
        expect(SessionService.currentToken, isNull);
      },
    );
  }
}
