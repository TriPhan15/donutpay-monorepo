import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/screens/profile/account_credentials_screen.dart';
import 'package:finance_ai_app/screens/profile/account_info_screen.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';

const String _mePath = '/api/users/me';
const String _updatePath = '/api/users/1';

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
      _mePath,
      (_) => okResponse({
        'id': 1,
        'email': 'an@example.com',
        'username': 'Nguyễn Văn An',
        'phone': '0912345678',
      }),
    );
  });

  tearDown(() {
    Intl.defaultLocale = null;
    AppToast.resetForTest();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(withAppSettings(const AccountInfoScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester, String rowKey) async {
    await tester.tap(find.byKey(ValueKey(rowKey)));
    await tester.pumpAndSettle();
  }

  Finder sheetField() => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(TextField),
  );

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('Lưu')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  List<RequestOptions> updates() =>
      backend.requests.where((r) => r.path == _updatePath).toList();

  testWidgets(
    'shows the band with initials, name and email, and the masked phone',
    (tester) async {
      await open(tester);

      expect(backend.calls, contains('GET $_mePath'));
      expect(find.text('NA'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsNWidgets(2));
      expect(find.text('an@example.com'), findsNWidgets(2));
      expect(find.text('******5678'), findsOneWidget);
      expect(find.text('Thông tin cá nhân'), findsOneWidget);
      expect(find.text('Bảo mật'), findsOneWidget);
      expect(find.text('Tên đăng nhập'), findsNothing);
    },
  );

  testWidgets('an account without a phone says it is not set', (tester) async {
    backend.on(
      'GET',
      _mePath,
      (_) => okResponse({'id': 1, 'email': 'an@example.com'}),
    );
    await open(tester);

    expect(find.text('Chưa cập nhật'), findsOneWidget);
  });

  testWidgets('the email row is locked and opens nothing', (tester) async {
    await open(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-row-email')),
        matching: find.byIcon(Icons.lock_outline_rounded),
      ),
      findsOneWidget,
    );
    await openSheet(tester, 'account-row-email');
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('editing the name sends the name only, then reloads', (
    tester,
  ) async {
    backend.on(
      'PUT',
      _updatePath,
      (_) => okResponse({'id': 1, 'username': 'Trần Bình'}),
    );
    await open(tester);
    await openSheet(tester, 'account-row-name');

    expect(find.text('Sửa họ và tên'), findsOneWidget);
    expect(
      tester.widget<TextField>(sheetField()).controller!.text,
      'Nguyễn Văn An',
    );
    await tester.enterText(sheetField(), '  Trần Bình ');
    await tapSave(tester);

    expect(updates().single.data, {'username': 'Trần Bình'});
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Đã lưu thông tin cá nhân.'), findsOneWidget);
    expect(backend.calls.where((c) => c == 'GET $_mePath'), hasLength(2));
  });

  testWidgets(
    'the reload after a save keeps the rows on screen, and its failure is only a toast',
    (tester) async {
      backend.on('PUT', _updatePath, (_) => okResponse({'id': 1}));
      await open(tester);
      final reload = Completer<ResponseBody>();
      backend.on('GET', _mePath, (_) => reload.future);
      await openSheet(tester, 'account-row-name');
      await tester.enterText(sheetField(), 'Trần Bình');
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Lưu'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AppStateView), findsNothing);
      expect(find.byKey(const ValueKey('account-row-name')), findsOneWidget);

      await withCapturedLogs((_) async {
        reload.complete(jsonResponse(500, {'code': 500, 'message': 'boom'}));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      });

      expect(find.byKey(const ValueKey('account-row-name')), findsOneWidget);
      expect(
        find.text('Không tải được thông tin cá nhân. Vui lòng thử lại.'),
        findsNothing,
      );
    },
  );

  testWidgets('editing the phone sends the phone only', (tester) async {
    backend.on('PUT', _updatePath, (_) => okResponse({'id': 1}));
    await open(tester);
    await openSheet(tester, 'account-row-phone');

    expect(find.text('Sửa số điện thoại'), findsOneWidget);
    expect(
      tester.widget<TextField>(sheetField()).controller!.text,
      '0912345678',
    );
    await tester.enterText(sheetField(), '0987654321');
    await tapSave(tester);

    // Without the name: a display name made from the email must never be written back as the username.
    expect(updates().single.data, {'phone': '0987654321'});
  });

  testWidgets(
    'a name made from the email is not sent when the sheet is saved unchanged',
    (tester) async {
      backend.on(
        'GET',
        _mePath,
        (_) => okResponse({
          'id': 1,
          'email': 'an@example.com',
          'username': 'an@example.com',
        }),
      );
      await open(tester);
      await openSheet(tester, 'account-row-name');
      expect(tester.widget<TextField>(sheetField()).controller!.text, 'an');

      await tapSave(tester);

      expect(updates(), isEmpty);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Đã lưu thông tin cá nhân.'), findsNothing);
    },
  );

  testWidgets(
    'an empty phone is refused: the server keeps the old one anyway',
    (tester) async {
      await open(tester);
      await openSheet(tester, 'account-row-phone');

      await tester.enterText(sheetField(), '  ');
      await tapSave(tester);

      expect(updates(), isEmpty);
      expect(find.text('Vui lòng nhập số điện thoại.'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    },
  );

  testWidgets('two quick taps on a row open one sheet', (tester) async {
    await open(tester);

    // Both taps land in the same frame, before the first sheet's barrier covers the row.
    final row = tester.widget<ListTile>(
      find.byKey(const ValueKey('account-row-name')),
    );
    row.onTap!();
    row.onTap!();
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await openSheet(tester, 'account-row-phone');
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('without an id in /me the save goes to the signed-in user', (
    tester,
  ) async {
    backend.on(
      'GET',
      _mePath,
      (_) =>
          okResponse({'email': 'an@example.com', 'username': 'Nguyễn Văn An'}),
    );
    backend.on('PUT', _updatePath, (_) => okResponse({'id': 1}));
    await open(tester);
    await openSheet(tester, 'account-row-name');

    await tester.enterText(sheetField(), 'Trần Bình');
    await tapSave(tester);

    expect(updates().single.data, {'username': 'Trần Bình'});
  });

  testWidgets('an empty name is refused before any request', (tester) async {
    await open(tester);
    await openSheet(tester, 'account-row-name');

    await tester.enterText(sheetField(), '   ');
    await tapSave(tester);

    expect(updates(), isEmpty);
    expect(find.text('Vui lòng nhập họ và tên.'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('an invalid phone is refused before any request', (tester) async {
    await open(tester);
    await openSheet(tester, 'account-row-phone');

    await tester.enterText(sheetField(), '12345');
    await tapSave(tester);

    expect(updates(), isEmpty);
    expect(
      find.text('Số điện thoại không hợp lệ (10 số, bắt đầu bằng 0).'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a failed save shows a fixed text, never the raw error, and keeps the sheet',
    (tester) async {
      backend.on(
        'PUT',
        _updatePath,
        (_) => jsonResponse(500, {
          'code': 500,
          'message': 'Hệ thống sự cố: org.hibernate.Exception',
        }),
      );
      await open(tester);
      await openSheet(tester, 'account-row-name');
      await tester.enterText(sheetField(), 'Trần Bình');

      await withCapturedLogs((logs) async {
        await tapSave(tester);
        expect(logs, isNotEmpty);
      });

      expect(find.text('Lưu thất bại'), findsOneWidget);
      expect(
        find.text('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'),
        findsOneWidget,
      );
      expect(find.textContaining('hibernate'), findsNothing);

      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(sheetField()).controller!.text,
        'Trần Bình',
      );
    },
  );

  testWidgets('a second tap on Lưu while saving sends one request', (
    tester,
  ) async {
    final answer = Completer<ResponseBody>();
    backend.on('PUT', _updatePath, (_) => answer.future);
    await open(tester);
    await openSheet(tester, 'account-row-name');
    await tester.enterText(sheetField(), 'Trần Bình');

    final save = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(FilledButton),
    );
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(save, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));

    expect(updates(), hasLength(1));
    answer.complete(okResponse({'id': 1}));
    await tester.pumpAndSettle();
  });

  testWidgets('a save answer after the screen is gone throws nothing', (
    tester,
  ) async {
    final answer = Completer<ResponseBody>();
    backend.on('PUT', _updatePath, (_) => answer.future);
    await open(tester);
    await openSheet(tester, 'account-row-name');
    await tester.enterText(sheetField(), 'Trần Bình');
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('Lưu')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());
    answer.complete(okResponse({'id': 1}));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed load offers Thử lại, which loads again', (
    tester,
  ) async {
    backend.on(
      'GET',
      _mePath,
      (_) => jsonResponse(500, {'code': 500, 'message': 'boom'}),
    );
    await withCapturedLogs((_) async => open(tester));

    expect(
      find.text('Không tải được thông tin cá nhân. Vui lòng thử lại.'),
      findsOneWidget,
    );

    backend.on(
      'GET',
      _mePath,
      (_) => okResponse({'id': 1, 'email': 'an@example.com'}),
    );
    await tester.tap(find.text('Thử lại'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('an@example.com'), findsNWidgets(2));
  });

  testWidgets('without a session it asks to sign in again and sends nothing', (
    tester,
  ) async {
    await SessionService.clearSession();
    SharedPreferences.setMockInitialValues({});
    await open(tester);

    expect(find.text('Vui lòng đăng nhập lại.'), findsOneWidget);
    expect(backend.calls, isNot(contains('GET $_mePath')));
  });

  testWidgets('Đổi mật khẩu opens the password page', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('account-change-password')));
    await tester.pumpAndSettle();

    expect(find.byType(AccountCredentialsScreen), findsOneWidget);
  });
}
