import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/screens/profile/savings_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';

const String _serverError = 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';

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
      '/api/savings',
      (_) => okResponse([
        {
          'id': 7,
          'title': 'Du lịch',
          'target': 10000000,
          'current': 2500000,
          'deadline': '31/12/2026',
        },
      ]),
    );
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(withAppSettings(const SavingsPage()));
    // The page waits 300 ms before it loads.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a load failure stops the spinner and says so with a fixed text',
    (tester) async {
      backend.on(
        'GET',
        '/api/savings',
        (_) => jsonResponse(500, {'code': 500}),
      );

      await withCapturedLogs((logs) async {
        await open(tester);
      });

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('Không tải được sổ tiết kiệm. $_serverError'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a refused delete puts the goal back and says so', (
    tester,
  ) async {
    backend.on(
      'DELETE',
      '/api/savings/7',
      (_) =>
          jsonResponse(500, {'code': 500, 'message': 'java.sql.SQLException'}),
    );
    await open(tester);

    await withCapturedLogs((logs) async {
      await tester.longPress(find.text('Du lịch'));
      await settle(tester);
    });

    expect(find.text('Du lịch'), findsOneWidget);
    expect(find.text('Không xóa được mục tiêu. $_serverError'), findsOneWidget);
    expect(find.textContaining('SQLException'), findsNothing);
  });

  testWidgets(
    'a failed add keeps the dialog and what was typed, with a fixed text',
    (tester) async {
      backend.on(
        'POST',
        '/api/savings',
        (_) =>
            jsonResponse(500, {'code': 500, 'message': 'NullPointerException'}),
      );
      await open(tester);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'Mua xe');
      await tester.enterText(fields.at(1), '50000000');

      await withCapturedLogs((logs) async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Thêm'));
        await settle(tester);
      });

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Mua xe'), findsOneWidget);
      expect(find.text(_serverError), findsOneWidget);
      expect(find.textContaining('NullPointer'), findsNothing);

      // Closing the dialog disposes its controllers with it: no error after the route is gone.
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  Finder dialogFields() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  testWidgets(
    'editing a goal sends title, target and deadline but never current',
    (tester) async {
      backend.on('PUT', '/api/savings/7', (_) => okResponse(null));
      await open(tester);

      await tester.tap(find.text('Du lịch'));
      await tester.pumpAndSettle();
      expect(find.text('Sửa mục tiêu Du lịch'), findsOneWidget);
      // Name and target only, filled in; no saved amount to change.
      expect(dialogFields(), findsNWidgets(2));
      await tester.enterText(dialogFields().at(0), 'Laptop');
      await tester.enterText(dialogFields().at(1), '20000000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu'));
      await settle(tester);

      final body =
          backend.requests.singleWhere((r) => r.method == 'PUT').data as Map;
      expect(body.containsKey('current'), isFalse);
      expect(body['title'], 'Laptop');
      expect(body['target'], 20000000);
      // The stored deadline is kept: the server would clear it if it were missing.
      expect(body['deadline'], '31/12/2026');
      expect(find.byType(AlertDialog), findsNothing);
      expect(backend.calls.where((c) => c == 'GET /api/savings'), hasLength(2));
    },
  );

  testWidgets('an emptied target keeps the dialog open and sends nothing', (
    tester,
  ) async {
    backend.on('PUT', '/api/savings/7', (_) => okResponse(null));
    await open(tester);

    await tester.tap(find.text('Du lịch'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogFields().at(1), '');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(backend.requests.where((r) => r.method == 'PUT'), isEmpty);
  });
}
