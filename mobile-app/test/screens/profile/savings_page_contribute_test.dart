import 'dart:async';

import 'package:dio/dio.dart';
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

import '../../helpers/app_settings_scope.dart';
import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';

const String _contributions = '/api/savings/7/contributions';
const String _insufficient = 'GIAO DỊCH THẤT BẠI: Số dư ví không đủ!';

/// Dio hands a request from one step to the next with zero-length timers, which only fire when the fake clock moves.
const Duration _requestStep = Duration(milliseconds: 100);

Map<String, Object?> _goal({
  num current = 2500000,
  num target = 10000000,
  String? deadline = '31/12/2026',
}) => {
  'id': 7,
  'title': 'Du lịch',
  'target': target,
  'current': current,
  'deadline': deadline,
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
    // Without a deadline: no suggestion, so the field starts empty.
    backend.on(
      'GET',
      '/api/savings',
      (_) => okResponse([_goal(deadline: null)]),
    );
    backend.on(
      'GET',
      '/api/users/me',
      (_) => okResponse({'id': 1, 'walletBalance': 12400000}),
    );
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

  /// Lets the toasts end, so no timer is left when the test is over.
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

  Future<void> openSheetWith(WidgetTester tester, String amount) async {
    await tester.tap(find.text('Du lịch'));
    await settle(tester);
    expect(find.byType(ContributeSheet), findsOneWidget);
    await tester.enterText(sheetField(), amount);
    await tester.pump();
  }

  Iterable<RequestOptions> contributionRequests() => backend.requests.where(
    (r) => r.method == 'POST' && r.path == _contributions,
  );

  group('Góp tiền', () {
    testWidgets(
      'tapping a goal opens the sheet; the grouped amount is sent once, the sheet closes, the list reloads',
      (tester) async {
        backend.on(
          'POST',
          _contributions,
          (_) => okResponse(_goal(current: 3000000)),
        );
        await open(tester);
        var changes = 0;
        void count() => changes++;
        RemoteApiHelper.instance.dataChangedNotifier.addListener(count);
        addTearDown(
          () => RemoteApiHelper.instance.dataChangedNotifier.removeListener(
            count,
          ),
        );

        await openSheetWith(tester, '500000');
        expect(
          tester.widget<TextField>(sheetField()).controller!.text,
          '500.000',
        );
        expect(
          find.text(
            'Trừ từ ví (số dư 12.400.000 đ) và ghi thành khoản chi "Tiết kiệm".',
          ),
          findsOneWidget,
        );
        await tester.tap(sheetButton());
        await settle(tester);

        expect(contributionRequests().single.data, {'amount': 500000.0});
        expect(find.byType(ContributeSheet), findsNothing);
        expect(find.text('Đã góp tiền vào "Du lịch"'), findsOneWidget);
        expect(changes, 1, reason: 'the Ledger and the balance reload on it');
        expect(
          backend.calls.where((c) => c == 'GET /api/savings'),
          hasLength(2),
        );
        await drainToasts(tester);
      },
    );

    testWidgets('a goal with a deadline opens with the suggestion', (
      tester,
    ) async {
      backend.on('GET', '/api/savings', (_) => okResponse([_goal()]));
      await open(tester);

      await tester.tap(find.text('Du lịch'));
      await settle(tester);

      expect(
        tester.widget<TextField>(sheetField()).controller!.text,
        isNotEmpty,
      );
      expect(find.text('Gợi ý'), findsOneWidget);
      expect(find.byKey(ContributeSheet.hintKey), findsOneWidget);
    });

    testWidgets(
      'reaching the target is congratulated, and the goal moves to Đã xong',
      (tester) async {
        backend.on('POST', _contributions, (_) {
          final reached = _goal(current: 10000000, deadline: null);
          // The reload after the write reads the goal as the server now has it.
          backend.on('GET', '/api/savings', (_) => okResponse([reached]));
          return okResponse(reached);
        });
        await open(tester);

        await openSheetWith(tester, '7500000');
        await tester.tap(sheetButton());
        await settle(tester);

        expect(
          find.text('Chúc mừng! Bạn đã đạt mục tiêu "Du lịch"'),
          findsOneWidget,
        );
        await drainToasts(tester);
        await tester.tap(find.text('Đã xong'));
        await tester.pumpAndSettle();
        expect(find.text('Du lịch'), findsOneWidget);
        expect(find.text('Đã đạt mục tiêu'), findsOneWidget);
      },
    );

    testWidgets(
      'a wallet that is too low is told with the server message, and the sheet stays with the amount',
      (tester) async {
        backend.on(
          'POST',
          _contributions,
          (_) => jsonResponse(400, {'code': 400, 'message': _insufficient}),
        );
        await open(tester);

        await withCapturedLogs((logs) async {
          await openSheetWith(tester, '900000000');
          await tester.tap(sheetButton());
          await settle(tester);
        });

        expect(
          find.text('Không góp được tiền. $_insufficient'),
          findsOneWidget,
        );
        expect(find.byType(ContributeSheet), findsOneWidget);
        expect(find.text('900.000.000'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(sheetButton()).onPressed,
          isNotNull,
          reason: 'the user may try again with another amount',
        );
        await drainToasts(tester);
      },
    );

    testWidgets(
      'a double tap sends one contribution, and the button is disabled while it runs',
      (tester) async {
        final answer = Completer<ResponseBody>();
        backend.on('POST', _contributions, (_) => answer.future);
        await open(tester);

        await openSheetWith(tester, '500000');
        await tester.tap(sheetButton());
        await tester.tap(sheetButton(), warnIfMissed: false);
        await tester.pump(_requestStep);

        expect(contributionRequests(), hasLength(1));
        expect(tester.widget<FilledButton>(sheetButton()).onPressed, isNull);

        answer.complete(okResponse(_goal(current: 3000000)));
        await settle(tester);

        expect(contributionRequests(), hasLength(1));
        expect(find.byType(ContributeSheet), findsNothing);
        await drainToasts(tester);
      },
    );

    testWidgets(
      'a sheet closed while the contribution runs still updates the list and says so',
      (tester) async {
        final answer = Completer<ResponseBody>();
        backend.on('POST', _contributions, (_) => answer.future);
        await open(tester);

        await openSheetWith(tester, '500000');
        await tester.tap(sheetButton());
        await tester.pump(_requestStep);
        await tester.tap(find.byKey(ContributeSheet.closeKey));
        await tester.pumpAndSettle();
        expect(find.byType(ContributeSheet), findsNothing);

        answer.complete(okResponse(_goal(current: 3000000)));
        await settle(tester);

        expect(find.text('Đã góp tiền vào "Du lịch"'), findsOneWidget);
        expect(
          backend.calls.where((c) => c == 'GET /api/savings'),
          hasLength(2),
        );
        await drainToasts(tester);
      },
    );

    testWidgets('an older load that answers last does not win', (tester) async {
      final slow = Completer<ResponseBody>();
      var calls = 0;
      backend.on('GET', '/api/savings', (_) {
        calls++;
        // The first load is slow and still has the goal; the second one (pull to refresh) no longer has it.
        if (calls == 1) return slow.future;
        return okResponse([]);
      });
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(withAppSettings(const SavingsPage()));
      await tester.pump(_requestStep);

      final state = tester.state<RefreshIndicatorState>(
        find.byType(RefreshIndicator),
      );
      unawaited(state.show());
      await settle(tester);
      expect(calls, 2);
      expect(find.text('Chưa có mục tiêu đang thực hiện'), findsOneWidget);

      slow.complete(okResponse([_goal()]));
      await settle(tester);
      expect(find.text('Du lịch'), findsNothing);
    });

    testWidgets('an empty amount cannot be sent', (tester) async {
      await open(tester);

      await openSheetWith(tester, '');

      expect(tester.widget<FilledButton>(sheetButton()).onPressed, isNull);
      expect(contributionRequests(), isEmpty);
    });
  });

  group('creating a goal', () {
    Future<Object?> addGoal(
      WidgetTester tester,
      Future<void> Function() fill,
    ) async {
      Object? sent;
      backend.on('POST', '/api/savings', (options) {
        sent = options.data;
        return okResponse(null);
      });
      await open(tester);
      await tester.tap(find.byKey(SavingsPage.addKey));
      await tester.pumpAndSettle();
      expect(find.byType(SavingsGoalFormPage), findsOneWidget);
      await fill();
      await tester.pump();
      await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
      await settle(tester);
      return sent;
    }

    Finder amountField() => find.descendant(
      of: find.byKey(SavingsGoalFormPage.amountKey),
      matching: find.byType(TextField),
    );

    testWidgets(
      'the + opens the form; a new goal is sent without a saved amount or date, the list reloads',
      (tester) async {
        final sent = await addGoal(tester, () async {
          await tester.enterText(
            find.byKey(SavingsGoalFormPage.nameKey),
            'Mua xe',
          );
          await tester.enterText(amountField(), '50000000');
        });

        expect(sent, {'title': 'Mua xe', 'target': 50000000.0});
        expect(find.byType(SavingsGoalFormPage), findsNothing);
        expect(find.text('Đã thêm mục tiêu: Mua xe'), findsOneWidget);
        expect(
          backend.calls.where((c) => c == 'GET /api/savings'),
          hasLength(2),
        );
        await drainToasts(tester);
      },
    );

    testWidgets('a picked target date is sent as dd/MM/yyyy', (tester) async {
      final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
      final sent = await addGoal(tester, () async {
        await tester.enterText(
          find.byKey(SavingsGoalFormPage.nameKey),
          'Mua xe',
        );
        await tester.enterText(amountField(), '50.000.000');
        await tester.tap(find.byKey(SavingsGoalFormPage.deadlineKey));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Hôm nay'));
        await tester.pumpAndSettle();
      });

      expect(sent, {
        'title': 'Mua xe',
        'target': 50000000.0,
        'deadline': today,
      });
      await drainToasts(tester);
    });
  });
}
