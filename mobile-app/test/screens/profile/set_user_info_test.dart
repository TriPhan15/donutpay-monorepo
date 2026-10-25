import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/screens/profile/set_user_info.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';

void main() {
  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    await SessionService.setTokens('access-token', 'refresh-token');
    SharedPreferences.setMockInitialValues({});
    backend.reset();
    backend.on(
      'GET',
      '/api/users/me',
      (_) => okResponse({
        'id': 1,
        'email': 'an@example.com',
        'username': 'an@example.com',
        'phone': '0912345678',
      }),
    );
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(const SetUserInfoScreen(userId: 1)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('the form is filled from /me, not from the local database', (
    tester,
  ) async {
    await open(tester);

    expect(backend.calls, contains('GET /api/users/me'));
    expect(find.text('an'), findsOneWidget, reason: 'the name shown elsewhere');
    expect(find.text('0912345678'), findsOneWidget);
  });

  testWidgets(
    'saving sends PUT /api/users/{id} with the fields of UserUpdateDto only',
    (tester) async {
      Object? sent;
      backend.on('PUT', '/api/users/1', (options) {
        sent = options.data;
        return okResponse({'id': 1, 'username': 'Nguyễn Văn An'});
      });
      await open(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Nguyễn Văn An');
      await tester.enterText(find.byType(TextField).at(1), '0987654321');
      await save(tester);

      expect(sent, {'username': 'Nguyễn Văn An', 'phone': '0987654321'});
      expect(find.text('Đã lưu thông tin cá nhân.'), findsOneWidget);
    },
  );

  testWidgets('a failed save shows a fixed text, never the raw error', (
    tester,
  ) async {
    backend.on(
      'PUT',
      '/api/users/1',
      (_) => jsonResponse(500, {
        'code': 500,
        'message': 'Hệ thống sự cố: org.hibernate.Exception',
      }),
    );
    await open(tester);

    await withCapturedLogs((logs) async {
      await save(tester);
      expect(logs, isNotEmpty);
    });

    expect(find.text('Lưu thất bại'), findsOneWidget);
    expect(
      find.text('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'),
      findsOneWidget,
    );
    expect(find.textContaining('hibernate'), findsNothing);
  });

  testWidgets('an invalid phone is refused before any request', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField).at(1), '12345');
    await save(tester);

    expect(backend.calls, isNot(contains('PUT /api/users/1')));
    expect(
      find.text('Số điện thoại không hợp lệ (10 số, bắt đầu bằng 0).'),
      findsOneWidget,
    );
  });
}
