import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/screens/profile/savings_page.dart';
import 'package:finance_ai_app/screens/savings/savings_goal_form_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';

const String _serverError = 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';

Map<String, Object?> _goal({num current = 2500000}) => {
  'id': 7,
  'title': 'Du lịch',
  'target': 10000000,
  'current': current,
  'deadline': '31/12/2026',
};

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
    backend.on('GET', '/api/savings', (_) => okResponse([_goal()]));
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(withAppSettings(const SavingsPage()));
    await settle(tester);
  }

  Future<void> drainToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  Future<void> swipe(WidgetTester tester) async {
    await tester.drag(find.text('Du lịch'), const Offset(-600, 0));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a load failure shows the error state with a fixed text, and Thử lại loads again',
    (tester) async {
      backend.on(
        'GET',
        '/api/savings',
        (_) => jsonResponse(500, {'code': 500}),
      );

      await withCapturedLogs((logs) async {
        await open(tester);
      });

      expect(find.byType(AppStateView), findsOneWidget);
      expect(find.text('Không tải được sổ tiết kiệm'), findsOneWidget);
      expect(find.text(_serverError), findsOneWidget);

      backend.on('GET', '/api/savings', (_) => okResponse([_goal()]));
      await tester.tap(find.text('Thử lại'));
      await settle(tester);
      expect(find.text('Du lịch'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed reload keeps the list on screen and says so in a toast',
    (tester) async {
      await open(tester);
      backend.on(
        'GET',
        '/api/savings',
        (_) => jsonResponse(500, {'code': 500}),
      );

      await withCapturedLogs((logs) async {
        final state = tester.state<RefreshIndicatorState>(
          find.byType(RefreshIndicator),
        );
        unawaited(state.show());
        await settle(tester);
      });

      expect(find.text('Du lịch'), findsOneWidget);
      expect(find.byType(AppStateView), findsNothing);
      expect(
        find.text('Không tải lại được sổ tiết kiệm. $_serverError'),
        findsOneWidget,
      );
      await drainToasts(tester);
    },
  );

  testWidgets('a goal without a target opens the form on tap, not the sheet', (
    tester,
  ) async {
    backend.on(
      'GET',
      '/api/savings',
      (_) => okResponse([
        {'id': 7, 'title': 'Du lịch', 'target': 0, 'current': 0},
      ]),
    );
    await open(tester);

    await tester.tap(find.text('Du lịch'));
    await tester.pumpAndSettle();

    expect(find.byType(SavingsGoalFormPage), findsOneWidget);
  });

  testWidgets('no goal: the empty state offers to add one', (tester) async {
    backend.on('GET', '/api/savings', (_) => okResponse([]));
    await open(tester);

    expect(find.text('Chưa có mục tiêu đang thực hiện'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Thêm mục tiêu'));
    await tester.pumpAndSettle();
    expect(find.byType(SavingsGoalFormPage), findsOneWidget);
  });

  testWidgets('a refused delete keeps the goal and says so', (tester) async {
    backend.on(
      'DELETE',
      '/api/savings/7',
      (_) =>
          jsonResponse(500, {'code': 500, 'message': 'java.sql.SQLException'}),
    );
    await open(tester);

    await withCapturedLogs((logs) async {
      await swipe(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
      await settle(tester);
    });

    expect(find.text('Du lịch'), findsOneWidget);
    expect(find.text('Không xóa được mục tiêu. $_serverError'), findsOneWidget);
    expect(find.textContaining('SQLException'), findsNothing);
    await drainToasts(tester);
  });

  group('deleting a goal asks first', () {
    const refundQuestion =
        'Xóa mục tiêu này? 2.500.000 đ đã góp sẽ được hoàn vào ví.';

    Iterable<RequestOptions> deletes() => backend.requests.where(
      (r) => r.method == 'DELETE' && r.path == '/api/savings/7',
    );

    setUp(() {
      backend.on('DELETE', '/api/savings/7', (_) => okResponse(null));
    });

    testWidgets('a swipe cancelled in the dialog sends nothing', (
      tester,
    ) async {
      await open(tester);

      await swipe(tester);
      expect(find.text(refundQuestion), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await settle(tester);

      expect(deletes(), isEmpty);
      expect(find.text('Du lịch'), findsOneWidget);
    });

    testWidgets(
      'a confirmed swipe sends the DELETE and the toast names the refund',
      (tester) async {
        await open(tester);

        await swipe(tester);
        await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
        await settle(tester);
        await settle(tester);

        expect(deletes(), hasLength(1));
        expect(find.text('Du lịch'), findsNothing);
        expect(
          find.text(
            'Đã xóa mục tiêu: Du lịch. 2.500.000 đ đã được hoàn vào ví.',
          ),
          findsOneWidget,
        );
        await drainToasts(tester);
      },
    );

    testWidgets(
      'a goal with nothing saved asks without a refund and the toast names none',
      (tester) async {
        backend.on(
          'GET',
          '/api/savings',
          (_) => okResponse([_goal(current: 0)]),
        );
        await open(tester);

        await swipe(tester);
        expect(find.text('Xóa mục tiêu này?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
        await settle(tester);
        await settle(tester);

        expect(deletes(), hasLength(1));
        expect(find.text('Đã xóa mục tiêu: Du lịch'), findsOneWidget);
        await drainToasts(tester);
      },
    );
  });

  group('editing a goal', () {
    Finder amountField() => find.descendant(
      of: find.byKey(SavingsGoalFormPage.amountKey),
      matching: find.byType(TextField),
    );

    testWidgets(
      'a long press opens the form; it sends title, target and deadline but never current',
      (tester) async {
        backend.on('PUT', '/api/savings/7', (_) => okResponse(null));
        await open(tester);

        await tester.longPress(find.text('Du lịch'));
        await tester.pumpAndSettle();
        expect(find.text('Sửa mục tiêu'), findsOneWidget);
        await tester.enterText(
          find.byKey(SavingsGoalFormPage.nameKey),
          'Laptop',
        );
        await tester.enterText(amountField(), '20000000');
        await tester.pump();
        await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
        await settle(tester);

        final body =
            backend.requests.singleWhere((r) => r.method == 'PUT').data as Map;
        expect(body.containsKey('current'), isFalse);
        expect(body['title'], 'Laptop');
        expect(body['target'], 20000000);
        // The stored deadline is kept: the server would clear it if it were missing.
        expect(body['deadline'], '31/12/2026');
        expect(find.byType(SavingsGoalFormPage), findsNothing);
        expect(find.text('Đã lưu mục tiêu: Laptop'), findsOneWidget);
        expect(
          backend.calls.where((c) => c == 'GET /api/savings'),
          hasLength(2),
        );
        await drainToasts(tester);
      },
    );

    testWidgets('a reached goal opens the form on tap, not the sheet', (
      tester,
    ) async {
      backend.on(
        'GET',
        '/api/savings',
        (_) => okResponse([_goal(current: 10000000)]),
      );
      await open(tester);

      await tester.tap(find.text('Đã xong'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Du lịch'));
      await tester.pumpAndSettle();

      expect(find.byType(SavingsGoalFormPage), findsOneWidget);
    });

    testWidgets(
      'a form closed while the save runs still reloads the list and says so',
      (tester) async {
        final answer = Completer<ResponseBody>();
        backend.on('PUT', '/api/savings/7', (_) => answer.future);
        await open(tester);

        await tester.longPress(find.text('Du lịch'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(SavingsGoalFormPage.nameKey),
          'Laptop',
        );
        await tester.pump();
        await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
        await tester.pump(const Duration(milliseconds: 100));
        // The close button of the band (the other ✕ clears the date).
        await tester.tap(
          find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == 'Đóng'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SavingsGoalFormPage), findsNothing);

        answer.complete(okResponse(null));
        await settle(tester);

        expect(find.text('Đã lưu mục tiêu: Laptop'), findsOneWidget);
        expect(
          backend.calls.where((c) => c == 'GET /api/savings'),
          hasLength(2),
        );
        await drainToasts(tester);
      },
    );

    testWidgets('a failed save keeps the form and what was typed', (
      tester,
    ) async {
      backend.on(
        'PUT',
        '/api/savings/7',
        (_) =>
            jsonResponse(500, {'code': 500, 'message': 'NullPointerException'}),
      );
      await open(tester);

      await tester.longPress(find.text('Du lịch'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(SavingsGoalFormPage.nameKey), 'Laptop');
      await tester.pump();
      await withCapturedLogs((logs) async {
        await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
        await settle(tester);
      });

      expect(find.text('Không lưu được mục tiêu'), findsOneWidget);
      expect(find.text(_serverError), findsOneWidget);
      expect(find.textContaining('NullPointer'), findsNothing);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(find.byType(SavingsGoalFormPage), findsOneWidget);
      expect(find.text('Laptop'), findsOneWidget);
    });
  });
}
