import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/profile/savings_page.dart';
import 'package:finance_ai_app/screens/savings/contribute_sheet.dart';
import 'package:finance_ai_app/screens/savings/savings_goal_form_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';

/// What the savings page does with an answer of the server that is missing, wrong or not what it expects. These pin the
/// behaviour that must stay the same when the requests return typed goals instead of raw maps.

const String _list = '/api/savings';
const String _me = '/api/users/me';
const String _contributions = '/api/savings/7/contributions';
const String _loadFailedTitle = 'Không tải được sổ tiết kiệm';
const String _walletLineNoBalance =
    'Trừ từ ví và ghi thành khoản chi "Tiết kiệm".';

/// Dio hands a request from one step to the next with zero-length timers, which only fire when the fake clock moves.
const Duration _requestStep = Duration(milliseconds: 100);

Map<String, Object?> _goal({num current = 2500000, String? deadline}) => {
  'id': 7,
  'title': 'Du lịch',
  'target': 10000000,
  'current': current,
  'deadline': deadline,
};

String _walletLine(String balance) =>
    'Trừ từ ví (số dư $balance) và ghi thành khoản chi "Tiết kiệm".';

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
    backend.on('GET', _list, (_) => okResponse([_goal()]));
    backend.on('GET', _me, (_) => okResponse({'id': 1, 'walletBalance': 5}));
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(_requestStep);
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

  Finder sheetField() => find.descendant(
    of: find.byKey(ContributeSheet.amountKey),
    matching: find.byType(TextField),
  );

  Finder sheetButton() => find.descendant(
    of: find.byType(ContributeSheet),
    matching: find.descendant(
      of: find.byType(FormSubmitBar),
      matching: find.byType(FilledButton),
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.text('Du lịch'));
    await settle(tester);
    expect(find.byType(ContributeSheet), findsOneWidget);
  }

  Finder amountField() => find.descendant(
    of: find.byKey(SavingsGoalFormPage.amountKey),
    matching: find.byType(TextField),
  );

  group('reading the goals', () {
    testWidgets('an answer without data is the empty list, not an error', (
      tester,
    ) async {
      backend.on('GET', _list, (_) => okResponse(null));
      await open(tester);

      expect(find.byType(AppStateView), findsOneWidget);
      expect(find.text('Chưa có mục tiêu đang thực hiện'), findsOneWidget);
      expect(find.text(_loadFailedTitle), findsNothing);
    });

    final malformed = {
      'data that is not a list': 'oops',
      'a goal that is not an object': [1],
    };
    malformed.forEach((how, data) {
      testWidgets('$how is a failed load: the error state, and one log', (
        tester,
      ) async {
        backend.on('GET', _list, (_) => okResponse(data));

        await withCapturedLogs((logs) async {
          await open(tester);
          expect(logs, hasLength(1));
          expect(logs.single, startsWith('Savings load failed'));
        });

        expect(find.text(_loadFailedTitle), findsOneWidget);
        expect(find.text('Du lịch'), findsNothing);
      });
    });
  });

  group('the wallet line of the sheet', () {
    testWidgets('names the balance the server keeps', (tester) async {
      backend.on(
        'GET',
        _me,
        (_) => okResponse({'id': 1, 'walletBalance': 12400000}),
      );
      await openSheet(tester);

      expect(find.text(_walletLine('12.400.000 đ')), findsOneWidget);
    });

    testWidgets('a balance of 0 is a balance, not a missing one', (
      tester,
    ) async {
      backend.on('GET', _me, (_) => okResponse({'id': 1, 'walletBalance': 0}));
      await openSheet(tester);

      expect(find.text(_walletLine('0 đ')), findsOneWidget);
    });

    testWidgets('a user without the field leaves the number out', (
      tester,
    ) async {
      backend.on('GET', _me, (_) => okResponse({'id': 1}));
      await openSheet(tester);

      expect(find.text(_walletLineNoBalance), findsOneWidget);
    });

    testWidgets('a refused request leaves the number out and logs it', (
      tester,
    ) async {
      backend.on('GET', _me, (_) => jsonResponse(500, {'code': 500}));

      await withCapturedLogs((logs) async {
        await openSheet(tester);
        expect(logs.single, startsWith('Savings wallet balance failed'));
      });

      expect(find.text(_walletLineNoBalance), findsOneWidget);
    });

    testWidgets('a balance that is not a number leaves it out and logs it', (
      tester,
    ) async {
      backend.on(
        'GET',
        _me,
        (_) => okResponse({'id': 1, 'walletBalance': 'a lot'}),
      );

      await withCapturedLogs((logs) async {
        await openSheet(tester);
        expect(logs.single, startsWith('Savings wallet balance failed'));
      });

      expect(find.text(_walletLineNoBalance), findsOneWidget);
    });
  });

  group('contributing', () {
    testWidgets(
      'an answer without the goal is a failure: the sheet stays, the list is not touched',
      (tester) async {
        backend.on('POST', _contributions, (_) => okResponse(null));
        await openSheet(tester);

        await withCapturedLogs((logs) async {
          await tester.enterText(sheetField(), '500000');
          await tester.pump();
          await tester.tap(sheetButton());
          await settle(tester);
          expect(logs.single, startsWith('Savings contribution failed'));
        });

        expect(find.textContaining('Không góp được tiền.'), findsOneWidget);
        expect(find.byType(ContributeSheet), findsOneWidget);
        expect(find.text('Đã góp tiền vào "Du lịch"'), findsNothing);
        expect(backend.calls.where((c) => c == 'GET $_list'), hasLength(1));
        await drainToasts(tester);
      },
    );

    testWidgets(
      'the goal the server returns replaces the row, with the title it had if the answer has none',
      (tester) async {
        backend.on(
          'POST',
          _contributions,
          (_) => okResponse({'id': 7, 'target': 10000000, 'current': 4000000}),
        );
        await openSheet(tester);

        await tester.enterText(sheetField(), '1500000');
        await tester.pump();
        await tester.tap(sheetButton());
        await settle(tester);

        expect(find.byType(ContributeSheet), findsNothing);
        expect(find.text('Đã góp tiền vào "Du lịch"'), findsOneWidget);
        await drainToasts(tester);
      },
    );
  });

  group('writing a goal', () {
    Future<void> save(WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(SavingsGoalFormPage), findsOneWidget);
      await tester.enterText(find.byKey(SavingsGoalFormPage.nameKey), 'Xe');
      await tester.enterText(amountField(), '3000000');
      await tester.pump();
      await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
      await settle(tester);
    }

    testWidgets('the answer to a new goal is not read: any body is a success', (
      tester,
    ) async {
      backend.on('POST', _list, (_) => okResponse('anything'));
      await open(tester);
      await tester.tap(find.byKey(SavingsPage.addKey));

      await save(tester);

      expect(find.text('Đã thêm mục tiêu: Xe'), findsOneWidget);
      expect(find.byType(SavingsGoalFormPage), findsNothing);
      expect(backend.calls.where((c) => c == 'GET $_list'), hasLength(2));
      await drainToasts(tester);
    });

    testWidgets('the answer to an edit is not read: any body is a success', (
      tester,
    ) async {
      backend.on('PUT', '/api/savings/7', (_) => okResponse('anything'));
      await open(tester);
      await tester.longPress(find.text('Du lịch'));

      await save(tester);

      expect(find.text('Đã lưu mục tiêu: Xe'), findsOneWidget);
      expect(find.byType(SavingsGoalFormPage), findsNothing);
      await drainToasts(tester);
    });

    testWidgets('an edit of a goal without a deadline still sends the key', (
      tester,
    ) async {
      backend.on('PUT', '/api/savings/7', (_) => okResponse(null));
      await open(tester);
      await tester.longPress(find.text('Du lịch'));

      await save(tester);

      final body =
          backend.requests.singleWhere((r) => r.method == 'PUT').data as Map;
      expect(body, {'title': 'Xe', 'target': 3000000.0, 'deadline': null});
      await drainToasts(tester);
    });
  });
}
