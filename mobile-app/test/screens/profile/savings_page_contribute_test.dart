import 'dart:async';

import 'package:dio/dio.dart';
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

const String _contributions = '/api/savings/7/contributions';
const ValueKey<String> _contributeKey = ValueKey('savings-contribute-7');
const String _insufficient = 'GIAO DỊCH THẤT BẠI: Số dư ví không đủ!';

/// Dio hands a request from one step to the next with zero-length timers, which only fire when the fake clock moves.
const Duration _requestStep = Duration(milliseconds: 100);

Map<String, Object?> _goal({num current = 2500000, num target = 10000000}) => {
  'id': 7,
  'title': 'Du lịch',
  'target': target,
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
    await tester.pump(_requestStep);
    await tester.pumpAndSettle();
  }

  /// Lets the toasts end, so no timer is left when the test is over.
  Future<void> drainToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  Finder sheetButton() => inSheet(find.byType(FilledButton));

  Future<void> openSheetWith(WidgetTester tester, String amount) async {
    await tester.tap(find.byKey(_contributeKey));
    await tester.pumpAndSettle();
    expect(find.text('Góp tiền: Du lịch'), findsOneWidget);
    await tester.enterText(inSheet(find.byType(TextField)), amount);
    await tester.pump();
  }

  Iterable<RequestOptions> contributionRequests() => backend.requests.where(
    (r) => r.method == 'POST' && r.path == _contributions,
  );

  group('Góp tiền', () {
    testWidgets(
      'sends the grouped amount once, closes the sheet, reloads and says so',
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
          tester
              .widget<TextField>(inSheet(find.byType(TextField)))
              .controller!
              .text,
          '500.000',
        );
        await tester.tap(sheetButton());
        await settle(tester);

        expect(contributionRequests().single.data, {'amount': 500000.0});
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('Đã góp tiền vào "Du lịch"'), findsOneWidget);
        expect(changes, 1, reason: 'the Ledger and the balance reload on it');
        expect(
          backend.calls.where((c) => c == 'GET /api/savings'),
          hasLength(2),
        );
        await drainToasts(tester);
      },
    );

    testWidgets('reaching the target is congratulated', (tester) async {
      backend.on(
        'POST',
        _contributions,
        (_) => okResponse(_goal(current: 10000000)),
      );
      await open(tester);

      await openSheetWith(tester, '7500000');
      await tester.tap(sheetButton());
      await settle(tester);

      expect(
        find.text('Chúc mừng! Bạn đã đạt mục tiêu "Du lịch"'),
        findsOneWidget,
      );
      await drainToasts(tester);
    });

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
        expect(find.byType(BottomSheet), findsOneWidget);
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
        await tester.tap(sheetButton());
        await tester.pump(_requestStep);

        expect(contributionRequests(), hasLength(1));
        expect(tester.widget<FilledButton>(sheetButton()).onPressed, isNull);

        answer.complete(okResponse(_goal(current: 3000000)));
        await settle(tester);

        expect(contributionRequests(), hasLength(1));
        expect(find.byType(BottomSheet), findsNothing);
        await drainToasts(tester);
      },
    );

    testWidgets('an empty amount sends nothing', (tester) async {
      await open(tester);

      await openSheetWith(tester, '');
      await tester.tap(sheetButton());
      await settle(tester);

      expect(contributionRequests(), isEmpty);
      expect(find.text('Nhập số tiền lớn hơn 0'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      await drainToasts(tester);
    });
  });

  group('creating a goal', () {
    Finder dialogFields() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

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
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await fill();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Thêm'));
      await settle(tester);
      return sent;
    }

    testWidgets(
      'a new goal is created without a saved amount, and with no date when none is picked',
      (tester) async {
        final sent = await addGoal(tester, () async {
          // Only the name and the target: the saved amount moves through contributions.
          expect(dialogFields(), findsNWidgets(2));
          await tester.enterText(dialogFields().at(0), 'Mua xe');
          await tester.enterText(dialogFields().at(1), '50000000');
        });

        expect(sent, {'title': 'Mua xe', 'target': 50000000.0});
        expect((sent as Map).containsKey('current'), isFalse);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets('a picked target date is sent as dd/MM/yyyy', (tester) async {
      final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
      final sent = await addGoal(tester, () async {
        await tester.enterText(dialogFields().at(0), 'Mua xe');
        await tester.enterText(dialogFields().at(1), '50.000.000');
        await tester.tap(find.text('Thêm ngày đạt mục tiêu (không bắt buộc)'));
        await tester.pumpAndSettle();
        expect(find.text('Ngày đạt mục tiêu'), findsOneWidget);
      });

      expect(sent, {
        'title': 'Mua xe',
        'target': 50000000.0,
        'deadline': today,
      });
    });

    testWidgets('a target date can be removed again', (tester) async {
      final sent = await addGoal(tester, () async {
        await tester.enterText(dialogFields().at(0), 'Mua xe');
        await tester.enterText(dialogFields().at(1), '50000000');
        await tester.tap(find.text('Thêm ngày đạt mục tiêu (không bắt buộc)'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Bỏ ngày đạt mục tiêu'));
        await tester.pumpAndSettle();
        expect(find.text('Ngày đạt mục tiêu'), findsNothing);
      });

      expect((sent as Map).containsKey('deadline'), isFalse);
    });
  });
}
